data "aws_caller_identity" "current" {}

data "aws_route53_zone" "root" {
  name         = local.root_domain
  private_zone = false
}

# ==================================================
# VPC
# ==================================================
module "vpc" {
  source             = "../../modules/vpc"
  project            = local.project
  env                = local.env
  region             = local.region
  cidr_block         = "10.0.0.0/16"
  availability_zones = local.availability_zones
}

# ==================================================
# Security Group
# ==================================================
data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${local.region}.s3"
}

data "aws_prefix_list" "dynamodb" {
  name = "com.amazonaws.${local.region}.dynamodb"
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
  vpc_id  = module.vpc.vpc_id
  name    = "lambda-comfyui-bff"
}

module "security_group_lambda_stop_comfyui" {
  source  = "../../modules/security_group"
  project = local.project
  env     = local.env
  name    = "lambda-stop-comfyui"
  vpc_id  = module.vpc.vpc_id
}

module "security_group_rule_ec2_comfyui" {
  source            = "../../modules/security_group_rule"
  security_group_id = module.security_group_ec2_comfyui.security_group_id
  ingress_from_sg = [
    {
      description                  = "request from Lambda(ComfyUI BFF)"
      referenced_security_group_id = module.security_group_lambda_comfyui_bff.security_group_id
      from_port                    = 8188
      to_port                      = 8188
      ip_protocol                  = "tcp"
    },
    {
      description                  = "request from Lambda(Stop ComfyUI)"
      referenced_security_group_id = module.security_group_lambda_stop_comfyui.security_group_id
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
      description                  = "request to EC2(ComfyUI)"
      referenced_security_group_id = module.security_group_ec2_comfyui.security_group_id
      from_port                    = 8188
      to_port                      = 8188
      ip_protocol                  = "tcp"
    }
  ]
  # egress_to_prefix_list = [
  #   {
  #     description    = "request to S3"
  #     prefix_list_id = data.aws_prefix_list.s3.id
  #     from_port      = 443
  #     to_port        = 443
  #     ip_protocol    = "tcp"
  #   },
  #   {
  #     description    = "request to DynamoDB"
  #     prefix_list_id = data.aws_prefix_list.dynamodb.id
  #     from_port      = 443
  #     to_port        = 443
  #     ip_protocol    = "tcp"
  #   }
  # ]
}

module "security_group_rule_lambda_stop_comfyui" {
  source            = "../../modules/security_group_rule"
  security_group_id = module.security_group_lambda_stop_comfyui.security_group_id
  egress_to_sg = [
    {
      description                  = "request to EC2(ComfyUI)"
      referenced_security_group_id = module.security_group_ec2_comfyui.security_group_id
      from_port                    = 8188
      to_port                      = 8188
      ip_protocol                  = "tcp"
    }
  ]
  # egress_to_prefix_list = [
  #   {
  #     description    = "request to S3"
  #     prefix_list_id = data.aws_prefix_list.s3.id
  #     from_port      = 443
  #     to_port        = 443
  #     ip_protocol    = "tcp"
  #   },
  #   {
  #     description    = "request to DynamoDB"
  #     prefix_list_id = data.aws_prefix_list.dynamodb.id
  #     from_port      = 443
  #     to_port        = 443
  #     ip_protocol    = "tcp"
  #   }
  # ]
}

# ==================================================
# S3
# ==================================================
module "s3_lambda_functions" {
  source            = "../../modules/s3"
  project           = local.project
  env               = local.env
  name              = "lambda-functions"
  enable_versioning = true
}

module "s3_private" {
  source  = "../../modules/s3"
  project = local.project
  env     = local.env
  name    = "private"
}

# ==================================================
# DynamoDB
# ==================================================
# ComfyUIインスタンスへの最終アクセス日時を管理
module "dynamodb_comfyui_status" {
  source       = "../../modules/dynamodb"
  project      = local.project
  env          = local.env
  name         = "comfyui-status"
  billing_mode = "PAY_PER_REQUEST"
  pk = {
    name = "id"
    type = "N"
  }
}

# ==================================================
# VPC Endpoint
# ==================================================
module "vpc_endpoint_gateway" {
  source = "../../modules/vpc_endpoint"
  region = local.region
  vpc_id = module.vpc.vpc_id
  gateway = [
    {
      service_name    = "s3"
      route_table_ids = [module.vpc.private_route_table_id]
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = "s3:*"
            Resource = [
              "arn:aws:s3:::${module.s3_private.bucket_id}",
              "arn:aws:s3:::${module.s3_private.bucket_id}/*"
            ]
          }
        ]
      })
    },
    {
      service_name    = "dynamodb"
      route_table_ids = [module.vpc.private_route_table_id]
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = "dynamodb:*"
            Resource = [
              "arn:aws:dynamodb:${local.region}:${data.aws_caller_identity.current.account_id}:table/${module.dynamodb_comfyui_status.table_name}"
            ]
          }
        ]
      })
    }
  ]
}

module "vpc_endpoint_interface" {
  source = "../../modules/vpc_endpoint"
  region = local.region
  vpc_id = module.vpc.vpc_id
  interface = [
    {
      service_name       = "ssm"
      subnet_ids         = module.vpc.private_subnet_ids
      security_group_ids = [module.security_group_ec2_comfyui.security_group_id]
    },
    {
      service_name       = "ssmmessages"
      subnet_ids         = module.vpc.private_subnet_ids
      security_group_ids = [module.security_group_ec2_comfyui.security_group_id]
    }
  ]
}

# ==================================================
# Secret Manager
# ==================================================
# CDN Private Key（apply後にCLIで秘密鍵の値に更新）
module "secret_manager_media_private_private_key" {
  source        = "../../modules/secret_manager"
  project       = local.project
  env           = local.env
  name          = "media-private-private-key"
  secret_string = "dummy"
}

# ==================================================
# CloudFront
# ==================================================
module "cloudfront_s3_private" {
  source             = "../../modules/cloudfront_s3"
  project            = local.project
  env                = local.env
  region             = local.region
  name               = "media-private"
  zone_id            = data.aws_route53_zone.root.zone_id
  domain_name        = "media.${local.root_domain}"
  s3_bucket_id       = module.s3_private.bucket_id
  trusted_public_key = var.media_private_public_key
}

# ==================================================
# Route53
# ==================================================
module "route53_vercel_cname" {
  source      = "../../modules/route53"
  zone_id     = data.aws_route53_zone.root.zone_id
  domain_name = "app.${local.root_domain}"
  cname = {
    ttl     = 300
    records = [var.vercel_cname_target]
  }
}

# ==================================================
# EC2
# ==================================================
module "ec2_comfyui" {
  source  = "../../modules/ec2"
  project = local.project
  env     = local.env
  name    = "comfyui"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
  inline_policy_json_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["arn:aws:s3:::${module.s3_private.bucket_id}/*"]
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
    delete_on_termination = false
  }
}

# ==================================================
# Lambda
# ==================================================
module "lambda_comfyui_bff" {
  source  = "../../modules/lambda"
  project = local.project
  env     = local.env
  name    = "comfyui-bff"
  inline_policy_json_documents = [
    jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["ec2:DescribeInstances", "ec2:StartInstances"]
          Resource = ["arn:aws:ec2:${local.region}:${data.aws_caller_identity.current.account_id}:instance/${module.ec2_comfyui.instance_id}"]
        },
        {
          Effect   = "Allow"
          Action   = ["dynamodb:GetItem", "dynamodb:PutItem"]
          Resource = ["arn:aws:dynamodb:${local.region}:${data.aws_caller_identity.current.account_id}:table/${module.dynamodb_comfyui_status.table_name}"]
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
    COMFYUI_INSTANCE_ID                 = module.ec2_comfyui.instance_id
    COMFYUI_STATUS_DYNAMO_DB_TABLE_NAME = module.dynamodb_comfyui_status.table_name
  }
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.security_group_lambda_comfyui_bff.security_group_id]
  }
  enable_function_url    = true
  function_url_auth_type = "AWS_IAM"
  function_url_cors = {
    allow_credentials = true
    allow_origins     = ["https://app.${local.root_domain}"]
    allow_methods     = ["GET", "POST"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age           = 300
  }
}

module "lambda_stop_comfyui" {
  source  = "../../modules/lambda"
  project = local.project
  env     = local.env
  name    = "stop-comfyui"
  inline_policy_json_documents = [
    jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["ec2:DescribeInstances", "ec2:StopInstances"]
          Resource = ["arn:aws:ec2:${local.region}:${data.aws_caller_identity.current.account_id}:instance/${module.ec2_comfyui.instance_id}"]
        },
        {
          Effect   = "Allow"
          Action   = ["dynamodb:GetItem", "dynamodb:PutItem"]
          Resource = ["arn:aws:dynamodb:${local.region}:${data.aws_caller_identity.current.account_id}:table/${module.dynamodb_comfyui_status.table_name}"]
        }
      ]
    }),
  ]
  source_dir   = "files/lambda/functions/stop_comfyui"
  output_path  = "outputs/lambda/functions/stop_comfyui.zip"
  s3_bucket_id = module.s3_lambda_functions.bucket_id
  s3_key       = "stop_comfyui.zip"
  handler      = "lambda_function.handler"
  runtime      = "nodejs22.x"
  environment = {
    COMFYUI_INSTANCE_ID                 = module.ec2_comfyui.instance_id
    COMFYUI_STATUS_DYNAMO_DB_TABLE_NAME = module.dynamodb_comfyui_status.table_name
  }
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.security_group_lambda_stop_comfyui.security_group_id]
  }
}

# ==================================================
# Scheduler
# ==================================================
module "scheduler_stop_comfyui" {
  source              = "../../modules/scheduler"
  project             = local.project
  env                 = local.env
  name                = "stop_comfyui"
  target_arn          = module.lambda_stop_comfyui.lambda_function_arn
  schedule_expression = "cron(0/5 * * * ? *)"
}
