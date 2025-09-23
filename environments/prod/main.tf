# ==================================================
# Network
# ==================================================
module "network" {
  source             = "../../modules/network"
  project            = local.project
  env                = local.env
  region             = local.region
  availability_zones = local.availability_zones
}

# ==================================================
# Security Group
# ==================================================
module "security_group" {
  source  = "../../modules/security_group"
  project = local.project
  env     = local.env
  vpc_id  = module.network.vpc_id
}

# ==================================================
# Secret Manager
# ==================================================
module "secretmanager" {
  source  = "../../modules/secret_manager"
  project = local.project
  env     = local.env
}

# ==================================================
# S3
# ==================================================
module "s3_lambda_functions" {
  source  = "../../modules/s3"
  project = local.project
  env     = local.env
  name = "lambda-functions"
  enable_versioning = true
}

module "s3_private" {
  source  = "../../modules/s3"
  project = local.project
  env     = local.env
  name = "private"
}

# ==================================================
# CloudFront
# ==================================================
module "cloudfront" {
  source                 = "../../modules/cloudfront"
  project                = local.project
  env                    = local.env
  root_domain            = local.root_domain
  cdn_public_key         = var.cdn_public_key
  cdn_bucket_id          = module.s3.private_bucket_id
  cdn_bucket_domain_name = module.s3.private_bucket_domain_name
}

# ==================================================
# Route53
# ==================================================
module "route53" {
  source                                  = "../../modules/route53"
  root_domain                             = local.root_domain
  vercel_cname_target                     = var.vercel_cname_target
  cloudfront_cdn_distribution_domain_name = module.cloudfront.cdn_distribution_domain_name
}

# ==================================================
# EC2
# ==================================================
module "ec2" {
  source                     = "../../modules/ec2"
  project                    = local.project
  env                        = local.env
  s3_private_bucket_id       = module.s3.private_bucket_id
  # Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.7 (Ubuntu 22.04) 20250907
  ami                        = "ami-0365bff494b18bf93"
  instance_type              = "g4dn.xlarge"
  private_subnet_id          = module.network.private_subnet_ids[0]
  comfyui_security_group_ids = [module.security_group.ec2_comfyui_security_group_id]
  ebs_volume_size            = 50
}

# ==================================================
# DynamoDB
# ==================================================
module "dynamodb" {
  source  = "../../modules/dynamodb"
  project = local.project
  env     = local.env
}

# ==================================================
# Lambda
# ==================================================
module "lambda_comfyui_bff" {
  source  = "../../modules/lambda"
  project = local.project
  env     = local.env
  name = "comfyui-bff"
  # TODO: 汎用化したら修正
  inline_policy_json_documents = [
    jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["ec2:DescribeInstances", "ec2:StartInstances"]
          Resource = ["arn:aws:ec2:${local.region}:${data.aws_caller_identity.current.account_id}:instance/${module.ec2.comfyui_instance_id}"]
        },
        {
          Effect = "Allow"
          Action = ["dynamodb:GetItem", "dynamodb:PutItem"]
          Resource = ["arn:aws:dynamodb:${local.region}:${data.aws_caller_identity.current.account_id}:table/${module.dynamodb.comfyui_instance_table_name}"]
        }
      ]
    }),
  ]
  source_dir = "files/lambda/functions/comfyui_bff"
  output_path = "outputs/lambda/functions/comfyui_bff.zip"
  s3_bucket_id = module.s3_lambda_functions.bucket_id
  s3_key = "comfyui_bff.zip"
  handler = "lambda_function.handler"
  runtime = "nodejs22.x"
  # TODO: 汎用化したら修正
  environment = {
    COMFYUI_INSTANCE_ID = module.ec2.comfyui_instance_id
    COMFYUI_STATUS_DYNAMO_DB_TABLE_NAME = module.dynamodb.comfyui_instance_table_name
  }
  # TODO: 汎用化したら修正
  vpc_config = {
    subnet_ids = module.network.private_subnet_ids
    security_group_ids = [module.security_group.ec2_comfyui_security_group_id]
  }
  enable_function_url = true
  function_url_auth_type = "AWS_IAM"
  function_url_cors = {
    allow_credentials = true
    allow_origins = ["https://app.${local.root_domain}"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["*"]
    expose_headers = ["*"]
    max_age = 300
  }
}

module "lambda_stop_comfyui" {
  source  = "../../modules/lambda"
  project = local.project
  env     = local.env
  name = "stop-comfyui"
  inline_policy_json_documents = [
    jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["ec2:DescribeInstances", "ec2:StopInstances"]
          Resource = ["arn:aws:ec2:${local.region}:${data.aws_caller_identity.current.account_id}:instance/${module.ec2.comfyui_instance_id}"]
        },
        {
          Effect = "Allow"
          Action = ["dynamodb:GetItem", "dynamodb:PutItem"]
          Resource = ["arn:aws:dynamodb:${local.region}:${data.aws_caller_identity.current.account_id}:table/${module.dynamodb.comfyui_instance_table_name}"]
        }
      ]
    }),
  ]
  source_dir = "files/lambda/functions/stop_comfyui"
  output_path = "outputs/lambda/functions/stop_comfyui.zip"
  s3_bucket_id = module.s3_lambda_functions.bucket_id
  s3_key = "stop_comfyui.zip"
  handler = "lambda_function.handler"
  runtime = "nodejs22.x"
  environment = {
    COMFYUI_INSTANCE_ID = module.ec2.comfyui_instance_id
    COMFYUI_STATUS_DYNAMO_DB_TABLE_NAME = module.dynamodb.comfyui_instance_table_name
  }
  vpc_config = {
    subnet_ids = module.network.private_subnet_ids
    security_group_ids = [module.security_group.ec2_comfyui_security_group_id]
  }
}

# ==================================================
# Scheduler
# ==================================================
module "scheduler_stop_comfyui" {
  source  = "../../modules/scheduler"
  project = local.project
  env     = local.env
  name = "stop_comfyui"
  target_arn = module.lambda_stop_comfyui.lambda_function_arn
  schedule_expression = "cron(0/5 * * * ? *)"
}
