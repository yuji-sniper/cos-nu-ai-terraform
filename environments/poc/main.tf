data "aws_caller_identity" "current" {}

# ==================================================
# VPC
# ==================================================
module "vpc" {
  source                            = "../../modules/vpc"
  project                           = local.project
  env                               = local.env
  region                            = local.region
  cidr_block                        = "10.1.0.0/16"
  private_subnet_availability_zones = local.availability_zones
  # TODO: NAT用。EC2でComfyUI関連のインストールが完了したら削除。
  public_subnet_availability_zones = local.availability_zones
}

# ==================================================
# NAT
# ==================================================
# TODO: EC2でComfyUI関連のインストールが完了したら削除
module "nat" {
  source                 = "../../modules/nat"
  project                = local.project
  env                    = local.env
  public_subnet_id       = module.vpc.public_subnet_ids[0]
  private_route_table_id = module.vpc.private_route_table_ids[0]
}

# ==================================================
# S3
# ==================================================
module "s3_lambda_functions" {
  source  = "../../modules/s3"
  project = local.project
  env     = local.env
  name    = "lambda-functions"
}

module "s3_private" {
  source  = "../../modules/s3"
  project = local.project
  env     = local.env
  name    = "private"
  force_destroy = true
}

# ==================================================
# Security Group
# ==================================================
data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${local.region}.s3"
}

module "security_group_ec2_comfyui" {
  source  = "../../modules/security_group"
  project = local.project
  env     = local.env
  name    = "ec2-comfyui"
  vpc_id  = module.vpc.vpc_id
}

module "security_group_lambda_comfyui_bff" {
  source  = "../../modules/security_group"
  project = local.project
  env     = local.env
  name    = "lambda-comfyui-bff"
  vpc_id  = module.vpc.vpc_id
}

module "security_group_vpce_ssm" {
  source  = "../../modules/security_group"
  project = local.project
  env     = local.env
  name    = "vpce-ssm"
  vpc_id  = module.vpc.vpc_id
}

module "security_group_vpce_ec2" {
  source  = "../../modules/security_group"
  project = local.project
  env     = local.env
  name    = "vpce-ec2"
  vpc_id  = module.vpc.vpc_id
}

module "security_group_rule_ec2_comfyui" {
  source            = "../../modules/security_group_rule"
  security_group_id = module.security_group_ec2_comfyui.security_group_id
  # TODO: EC2でComfyUI関連のインストールが完了したら削除
  allow_egress_to_all = true
  egress_to_sg = [
    {
      description                  = "request to VPC Endpoint(SSM)"
      referenced_security_group_id = module.security_group_vpce_ssm.security_group_id
      from_port                    = 443
      to_port                      = 443
      ip_protocol                  = "tcp"
    }
  ]
  egress_to_prefix_list = [
    {
      description    = "request to VPC Endpoint(S3)"
      prefix_list_id = data.aws_prefix_list.s3.id
      from_port      = 443
      to_port        = 443
      ip_protocol    = "tcp"
    }
  ]
  ingress_from_sg = [
    {
      description                  = "request from Lambda(ComfyUI BFF)"
      referenced_security_group_id = module.security_group_lambda_comfyui_bff.security_group_id
      from_port                    = 8188
      to_port                      = 8188
      ip_protocol                  = "tcp"
    }
  ]
}

module "security_group_rule_lambda_comfyui_bff" {
  source            = "../../modules/security_group_rule"
  security_group_id = module.security_group_lambda_comfyui_bff.security_group_id
  egress_to_sg = [
    {
      description                  = "request to VPC Endpoint(EC2)"
      referenced_security_group_id = module.security_group_vpce_ec2.security_group_id
      from_port                    = 443
      to_port                      = 443
      ip_protocol                  = "tcp"
    },
    {
      description                  = "request to EC2(ComfyUI)"
      referenced_security_group_id = module.security_group_ec2_comfyui.security_group_id
      from_port                    = 8188
      to_port                      = 8188
      ip_protocol                  = "tcp"
    }
  ]
}

module "security_group_rule_vpce_ssm" {

  source            = "../../modules/security_group_rule"
  security_group_id = module.security_group_vpce_ssm.security_group_id
  ingress_from_sg = [
    {
      description                  = "request from EC2(ComfyUI)"
      referenced_security_group_id = module.security_group_ec2_comfyui.security_group_id
      from_port                    = 443
      to_port                      = 443
      ip_protocol                  = "tcp"
    }
  ]
}

module "security_group_rule_vpce_ec2" {
  source            = "../../modules/security_group_rule"
  security_group_id = module.security_group_vpce_ec2.security_group_id
  ingress_from_sg = [
    {
      description                  = "request from Lambda(ComfyUI BFF)"
      referenced_security_group_id = module.security_group_lambda_comfyui_bff.security_group_id
      from_port                    = 443
      to_port                      = 443
      ip_protocol                  = "tcp"
    }
  ]
}

# ==================================================
# VPC Endpoint
# ==================================================
module "vpc_endpoint" {
  source = "../../modules/vpc_endpoint"
  region = local.region
  vpc_id = module.vpc.vpc_id
  gateway = [
    {
      service_name    = "com.amazonaws.${local.region}.s3"
      route_table_ids = [module.vpc.private_route_table_ids[0]]
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = "*"
            Action = ["s3:*"]
            Resource = ["*"]
          }
        ]
      })
    }
  ]
  interface = [
    {
      service_name       = "com.amazonaws.${local.region}.ssm"
      subnet_ids         = [module.vpc.private_subnet_ids[0]]
      security_group_ids = [module.security_group_vpce_ssm.security_group_id]
    },
    {
      service_name       = "com.amazonaws.${local.region}.ssmmessages"
      subnet_ids         = [module.vpc.private_subnet_ids[0]]
      security_group_ids = [module.security_group_vpce_ssm.security_group_id]
    },
    {
      service_name       = "com.amazonaws.${local.region}.ec2"
      subnet_ids         = [module.vpc.private_subnet_ids[0]]
      security_group_ids = [module.security_group_vpce_ec2.security_group_id]
    }
  ]
}

# ==================================================
# EC2
# ==================================================
data "cloudinit_config" "comfyui" {
  gzip          = false
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = yamlencode({
      write_files = [
        {
          path = "/home/ubuntu/setup.sh"
          content = templatefile("${path.module}/files/ec2/user_data/comfyui/scripts/setup.sh.tftpl", {
            region = local.region
            private_bucket_name = module.s3_private.bucket_id
          })
          owner = "ubuntu:ubuntu"
          permissions = "0755"
        }
      ]
    })
  }
}

module "ec2_comfyui" {
  source                      = "../../modules/ec2"
  project                     = local.project
  env                         = local.env
  name                        = "comfyui"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
  inline_policy_json_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${module.s3_private.bucket_id}",
          "arn:aws:s3:::${module.s3_private.bucket_id}/*"
        ]
      }
    ]
  })
  ami                         = "ami-0365bff494b18bf93"
  instance_type               = "g4dn.xlarge"
  subnet_id                   = module.vpc.private_subnet_ids[0]
  security_group_ids          = [module.security_group_ec2_comfyui.security_group_id]
  associate_public_ip_address = false
  root_block_device = {
    volume_size           = 50
    volume_type           = "gp3"
    iops                  = 3000
    encrypted             = true
    delete_on_termination = true
  }
  user_data_base64 = data.cloudinit_config.comfyui.rendered
  user_data_replace_on_change = true
}

# ==================================================
# Lambda
# ==================================================
module "lambda_comfyui_bff" {
  source       = "../../modules/lambda"
  project      = local.project
  env          = local.env
  name         = "comfyui-bff"
  inline_policy_json_documents = [
    jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["ec2:DescribeInstances"]
          Resource = ["*"]
        }
      ]
    }),
  ]
  source_dir   = "files/lambda/functions/comfyui_bff"
  output_path  = "outputs/lambda/functions/comfyui_bff.zip"
  s3_bucket_id = module.s3_lambda_functions.bucket_id
  s3_key       = "comfyui_bff.zip"
  handler      = "lambda_function.handler"
  runtime      = "nodejs22.x"
  environment = {
    COMFYUI_INSTANCE_ID = module.ec2_comfyui.instance_id
  }
  vpc_config = {
    subnet_ids         = [module.vpc.private_subnet_ids[0]]
    security_group_ids = [module.security_group_lambda_comfyui_bff.security_group_id]
  }
  enable_function_url    = true
  function_url_auth_type = "AWS_IAM"
  function_url_cors = {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["GET", "POST"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age           = 300
  }
}

# ==================================================
# IAM User
# ==================================================
# 関数URL呼び出し用
module "iam_user_lambda_comfyui_bff_function_url_invoke" {
  source  = "../../modules/iam_user"
  project = local.project
  env     = local.env
  name    = "lambda-comfyui-bff-function-url-invoke"
  inline_policy_json_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunctionUrl"]
        Resource = [module.lambda_comfyui_bff.lambda_function_arn]
        Condition = {
          StringEquals = {
            "lambda:FunctionUrlAuthType" = "AWS_IAM"
          }
        }
      }
    ]
  })
}
