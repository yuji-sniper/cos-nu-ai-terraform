data "aws_caller_identity" "current" {}

data "aws_region" "apne1" {
  provider = aws.apne1
}

# ==================================================
# Route53
# ==================================================
module "route53_zone" {
  source = "../../modules/route53_zone"
  name   = local.domain
}

module "route53_record_app_a" {
  source      = "../../modules/route53_record"
  zone_id     = module.route53_zone.zone_id
  domain_name = local.domain
  type        = "A"
  ttl         = 900
  records = [
    var.vercel_apex_a_record_ip
  ]
}

module "route53_record_admin_cname" {
  source      = "../../modules/route53_record"
  zone_id     = module.route53_zone.zone_id
  domain_name = "admin.${local.domain}"
  type        = "CNAME"
  ttl         = 900
  records = [
    var.vercel_admin_cname_target
  ]
}

# ==================================================
# SSM Parameter
# ==================================================
# CloudFront Private Key
module "ssm_parameter_cloudfront_media_private_key" {
  providers = {
    aws = aws.apne1
  }
  source = "../../modules/ssm_parameter"
  name   = "/cloudfront/media/private-key"
  type   = "SecureString"
  value  = "dummy"
}

# Supabase url
module "ssm_parameter_supabase_url" {
  source = "../../modules/ssm_parameter"
  name   = "/supabase/url"
  type   = "SecureString"
  value  = "dummy"
}

# Supabase service role key
module "ssm_parameter_supabase_service_role_key" {
  source = "../../modules/ssm_parameter"
  name   = "/supabase/service-role-key"
  type   = "SecureString"
  value  = "dummy"
}

# CIVITAI API Key
module "ssm_parameter_civitai_api_key" {
  source = "../../modules/ssm_parameter"
  name   = "/civitai/api-key"
  type   = "SecureString"
  value  = "dummy"
}

# ==================================================
# S3
# ==================================================
# lambda functions
module "s3_lambda_functions" {
  source            = "../../modules/s3"
  name              = "${local.project}-${local.env}-${local.region}-lambda-functions"
  enable_versioning = true
  force_destroy     = true
}

# private
module "s3_private" {
  source            = "../../modules/s3"
  name              = "${local.project}-${local.env}-${local.region}-private"
  enable_versioning = true
  force_destroy     = true
  cors_rules = [
    {
      allowed_origins = ["https://${local.domain}"]
      allowed_methods = ["POST"]
      allowed_headers = ["*"]
      max_age_seconds = 3600
    }
  ]
}

# ==================================================
# DynamoDB
# ==================================================
# generation job
module "dynamodb_generation_job" {
  source       = "../../modules/dynamodb"
  name         = "generation-job"
  billing_mode = "PAY_PER_REQUEST"
  pk = {
    name = "workflow_job_id"
    type = "S"
  }
  ttl = {
    attribute_name = "ttl"
  }
}

# ComfyUIインスタンスへの最終アクセス日時を管理
module "dynamodb_comfyui_last_access_at" {
  source       = "../../modules/dynamodb"
  name         = "comfyui-last-access-at"
  billing_mode = "PAY_PER_REQUEST"
  pk = {
    name = "id"
    type = "N"
  }
  item = jsonencode({
    id             = { N = "0" },
    last_access_at = { S = timestamp() }
  })
}

# ==================================================
# CloudFront
# ==================================================
# media
module "cloudfront_s3_media" {
  source                = "../../modules/cloudfront_s3"
  name                  = "media"
  zone_id               = module.route53_zone.zone_id
  domain_name           = "media.${local.domain}"
  s3_bucket_id          = module.s3_private.bucket_id
  s3_bucket_domain_name = module.s3_private.bucket_domain_name
  encoded_public_key    = file("${path.module}/.keys/cloudfront/media.public_key.pem")
}

# ==================================================
# VPC
# ==================================================
module "vpc_main" {
  source                            = "../../modules/vpc"
  name                              = "main"
  region                            = local.region
  cidr_block                        = "10.0.0.0/16"
  private_subnet_availability_zones = local.availability_zones
  # TODO: EC2でComfyUIのインストールが完了したら削除
  # public_subnet_availability_zones = local.availability_zones
}

# ==================================================
# NAT
# ==================================================
# TODO: EC2でComfyUIのインストールが完了したら削除
# module "nat_main" {
#   source = "../../modules/nat"
#   name   = "main"
#   public_subnet_id = module.vpc_main.public_subnet_ids[0]
#   private_route_table_id = module.vpc_main.private_route_table_ids[0]
# }

# ==================================================
# Security Group
# ==================================================
# Prefix List
data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${local.region}.s3"
}

data "aws_prefix_list" "dynamodb" {
  name = "com.amazonaws.${local.region}.dynamodb"
}

# Security Group
module "security_group_ec2_comfyui" {
  source = "../../modules/security_group"
  name   = "ec2-comfyui"
  vpc_id = module.vpc_main.vpc_id
}

module "security_group_lambda_generation_job" {
  source = "../../modules/security_group"
  name   = "lambda-generation-job"
  vpc_id = module.vpc_main.vpc_id
}

module "security_group_lambda_stop_comfyui_instance" {
  source = "../../modules/security_group"
  name   = "lambda-stop-comfyui-instance"
  vpc_id = module.vpc_main.vpc_id
}

module "security_group_vpc_endpoint_ssm_main" {
  source = "../../modules/security_group"
  name   = "vpc-endpoint-ssm-main"
  vpc_id = module.vpc_main.vpc_id
}

# Security Group Rule
module "security_group_rule_ec2_comfyui" {
  source            = "../../modules/security_group_rule"
  security_group_id = module.security_group_ec2_comfyui.security_group_id
  # TODO: EC2でComfyUI関連のインストールが完了したら削除
  allow_egress_to_all = true
  egress_to_sg = [
    {
      description                  = "request to VPC Endpoint(SSM)"
      referenced_security_group_id = module.security_group_vpc_endpoint_ssm_main.security_group_id
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
      description                  = "request from Lambda(Generation Job)"
      referenced_security_group_id = module.security_group_lambda_generation_job.security_group_id
      from_port                    = 8188
      to_port                      = 8188
      ip_protocol                  = "tcp"
    },
    {
      description                  = "request from Lambda(Stop ComfyUI Instance)"
      referenced_security_group_id = module.security_group_lambda_stop_comfyui_instance.security_group_id
      from_port                    = 8188
      to_port                      = 8188
      ip_protocol                  = "tcp"
    }
  ]
}

module "security_group_rule_lambda_generation_job" {
  source            = "../../modules/security_group_rule"
  security_group_id = module.security_group_lambda_generation_job.security_group_id
  egress_to_sg = [
    {
      description                  = "request to EC2(ComfyUI)"
      referenced_security_group_id = module.security_group_ec2_comfyui.security_group_id
      from_port                    = 8188
      to_port                      = 8188
      ip_protocol                  = "tcp"
    }
  ]
  egress_to_prefix_list = [
    {
      description    = "request to S3"
      prefix_list_id = data.aws_prefix_list.s3.id
      from_port      = 443
      to_port        = 443
      ip_protocol    = "tcp"
    },
    {
      description    = "request to DynamoDB"
      prefix_list_id = data.aws_prefix_list.dynamodb.id
      from_port      = 443
      to_port        = 443
      ip_protocol    = "tcp"
    }
  ]
}

module "security_group_rule_lambda_stop_comfyui_instance" {
  source            = "../../modules/security_group_rule"
  security_group_id = module.security_group_lambda_stop_comfyui_instance.security_group_id
  egress_to_sg = [
    {
      description                  = "request to EC2(ComfyUI)"
      referenced_security_group_id = module.security_group_ec2_comfyui.security_group_id
      from_port                    = 8188
      to_port                      = 8188
      ip_protocol                  = "tcp"
    }
  ]
  egress_to_prefix_list = [
    {
      description    = "request to DynamoDB"
      prefix_list_id = data.aws_prefix_list.dynamodb.id
      from_port      = 443
      to_port        = 443
      ip_protocol    = "tcp"
    }
  ]
}

module "security_group_rule_vpc_endpoint_ssm_main" {
  source            = "../../modules/security_group_rule"
  security_group_id = module.security_group_vpc_endpoint_ssm_main.security_group_id
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

# ==================================================
# VPC Endpoint
# ==================================================
module "vpc_endpoint_main" {
  source   = "../../modules/vpc_endpoint"
  region   = local.region
  vpc_id   = module.vpc_main.vpc_id
  vpc_name = module.vpc_main.vpc_name
  gateway = [
    {
      service_name    = "com.amazonaws.${local.region}.s3"
      route_table_ids = module.vpc_main.private_route_table_ids
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect    = "Allow"
            Principal = "*"
            Action    = "s3:*"
            Resource = [
              module.s3_private.bucket_arn,
              "${module.s3_private.bucket_arn}/*"
            ]
          }
        ]
      })
    },
    {
      service_name    = "com.amazonaws.${local.region}.dynamodb"
      route_table_ids = module.vpc_main.private_route_table_ids
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect    = "Allow"
            Principal = "*"
            Action    = "dynamodb:*"
            Resource = [
              module.dynamodb_generation_job.arn
            ]
          }
        ]
      })
    }
  ]
  interface = [
    {
      service_name       = "com.amazonaws.${local.region}.ssm"
      subnet_ids         = module.vpc_main.private_subnet_ids
      security_group_ids = [module.security_group_vpc_endpoint_ssm_main.security_group_id]
    },
    {
      service_name       = "com.amazonaws.${local.region}.ssmmessages"
      subnet_ids         = module.vpc_main.private_subnet_ids
      security_group_ids = [module.security_group_vpc_endpoint_ssm_main.security_group_id]
    },
    {
      service_name       = "com.amazonaws.${local.region}.ec2messages"
      subnet_ids         = module.vpc_main.private_subnet_ids
      security_group_ids = [module.security_group_vpc_endpoint_ssm_main.security_group_id]
    }
  ]
}

# ==================================================
# SQS
# ==================================================
module "sqs_generation_job" {
  source = "../../modules/sqs"
  name   = "generation-job"
  # 「Lambdaタイムアウト時間 × リトライ回数」以内に再実行されないようにするため
  visibility_timeout_seconds = 300 * 6
  message_retention_seconds  = 86400
  max_retry_count            = 3
  deadletter_retention_days  = 14
}

# ==================================================
# Lambda Layer
# ==================================================
# Supabase (Node.js)
module "lambda_layer_supabase_nodejs" {
  source              = "../../modules/lambda_layer"
  name                = "nodejs-supabase"
  source_dir          = "${path.module}/sources/lambda_layer/nodejs/supabase"
  output_path         = "${path.module}/outputs/lambda_layer/nodejs_supabase.zip"
  s3_bucket_id        = module.s3_lambda_functions.bucket_id
  s3_key              = "nodejs_supabase.zip"
  compatible_runtimes = ["nodejs22.x"]
}

# uuidv7 (Node.js)
module "lambda_layer_uuidv7_nodejs" {
  source              = "../../modules/lambda_layer"
  name                = "nodejs-uuidv7"
  source_dir          = "${path.module}/sources/lambda_layer/nodejs/uuidv7"
  output_path         = "${path.module}/outputs/lambda_layer/nodejs_uuidv7.zip"
  s3_bucket_id        = module.s3_lambda_functions.bucket_id
  s3_key              = "nodejs_uuidv7.zip"
  compatible_runtimes = ["nodejs22.x"]
}

# ==================================================
# Lambda
# ==================================================
# 生成ジョブ（VPC内）
module "lambda_generation_job" {
  source       = "../../modules/lambda"
  name         = "generation-job"
  handler      = "index.handler"
  runtime      = "nodejs22.x"
  timeout      = 300
  memory_size  = 128
  publish      = true
  source_dir   = "${path.module}/sources/lambda/generation_job"
  output_path  = "${path.module}/outputs/lambda/generation_job.zip"
  s3_bucket_id = module.s3_lambda_functions.bucket_id
  s3_key       = "generation-job/index.zip"
  vpc_config = {
    subnet_ids         = module.vpc_main.private_subnet_ids
    security_group_ids = [module.security_group_lambda_generation_job.security_group_id]
  }
  environment = {
    DYNAMODB_GENERATION_JOB_TABLE_NAME = module.dynamodb_generation_job.table_name
    DYNAMODB_GENERATION_JOB_REGION     = local.region
  }
  inline_policy_json_documents = [
    {
      name = "LambdaGenerationJobPolicy"
      document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          # SQS
          {
            Effect = "Allow"
            Action = [
              "sqs:ReceiveMessage",
              "sqs:DeleteMessage",
              "sqs:GetQueueAttributes",
            ]
            Resource = [module.sqs_generation_job.arn]
          },
          # DynamoDB
          {
            Effect   = "Allow"
            Action   = ["dynamodb:GetItem"]
            Resource = [module.dynamodb_generation_job.arn]
          }
        ]
      })
    }
  ]
  event_source_mapping = {
    event_source_arn = module.sqs_generation_job.arn
    batch_size       = 1
    scaling_config = {
      maximum_concurrency = 2
    }
  }
}

# 生成物データ保存
module "lambda_save_generation_artifact_data" {
  source       = "../../modules/lambda"
  name         = "save-generation-artifact-data"
  handler      = "index.handler"
  runtime      = "nodejs22.x"
  timeout      = 30
  memory_size  = 128
  publish      = true
  source_dir   = "${path.module}/sources/lambda/save_generation_artifact_data"
  output_path  = "${path.module}/outputs/lambda/save_generation_artifact_data.zip"
  s3_bucket_id = module.s3_lambda_functions.bucket_id
  s3_key       = "save_generation_artifact_data/index.zip"
  layer_arns = [
    module.lambda_layer_supabase_nodejs.arn,
    module.lambda_layer_uuidv7_nodejs.arn,
  ]
  environment = {
    SSM_PARAMETER_NAME_SUPABASE_URL              = module.ssm_parameter_supabase_url.name
    SSM_PARAMETER_NAME_SUPABASE_SERVICE_ROLE_KEY = module.ssm_parameter_supabase_service_role_key.name
  }
  inline_policy_json_documents = [
    {
      name = "LambdaSaveGenerationArtifactDataPolicy"
      document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          # SSM
          {
            Effect = "Allow"
            Action = "ssm:GetParameter"
            Resource = [
              module.ssm_parameter_supabase_url.arn,
              module.ssm_parameter_supabase_service_role_key.arn,
            ]
          },
          # S3
          {
            Effect = "Allow"
            Action = ["s3:DeleteObject"]
            Resource = [
              "arn:aws:s3:::${module.s3_private.bucket_id}/*",
            ]
          },
        ]
      })
    }
  ]
  permission = {
    statement_id = "AllowSaveGenerationArtifactDataLambdaExecutionFromS3Private"
    action       = "lambda:InvokeFunction"
    principal    = "s3.amazonaws.com"
    source_arn   = "arn:aws:s3:::${module.s3_private.bucket_id}"
  }
}

# inputsを一定枚数以下に保つ
module "lambda_enforce_private_inputs_object_limit" {
  source       = "../../modules/lambda"
  name         = "enforce-private-inputs-object-limit"
  handler      = "index.handler"
  runtime      = "nodejs22.x"
  timeout      = 30
  memory_size  = 128
  publish      = true
  source_dir   = "${path.module}/sources/lambda/enforce_private_inputs_object_limit"
  output_path  = "${path.module}/outputs/lambda/enforce_private_inputs_object_limit.zip"
  s3_bucket_id = module.s3_lambda_functions.bucket_id
  s3_key       = "enforce_private_inputs_object_limit/index.zip"
  environment = {
    LIMIT = 15
  }
  inline_policy_json_documents = [
    {
      name = "LambdaEnforcePrivateInputsObjectLimitPolicy"
      document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          # S3
          {
            Effect = "Allow"
            Action = ["s3:ListBucket", "s3:DeleteObject"]
            Resource = [
              "arn:aws:s3:::${module.s3_private.bucket_id}",
              "arn:aws:s3:::${module.s3_private.bucket_id}/*"
            ]
          },
        ]
      })
    }
  ]
  permission = {
    statement_id = "AllowEnforcePrivateInputsObjectLimitLambdaExecutionFromS3Private"
    action       = "lambda:InvokeFunction"
    principal    = "s3.amazonaws.com"
    source_arn   = "arn:aws:s3:::${module.s3_private.bucket_id}"
  }
}

# ComfyUIインスタンスを停止
module "lambda_stop_comfyui_instance" {
  source       = "../../modules/lambda"
  name         = "stop-comfyui-instance"
  handler      = "index.handler"
  runtime      = "nodejs22.x"
  timeout      = 30
  memory_size  = 128
  source_dir   = "${path.module}/sources/lambda/stop_comfyui_instance"
  output_path  = "${path.module}/outputs/lambda/stop_comfyui_instance.zip"
  s3_bucket_id = module.s3_lambda_functions.bucket_id
  s3_key       = "stop_comfyui_instance/index.zip"
  vpc_config = {
    subnet_ids         = module.vpc_main.private_subnet_ids
    security_group_ids = [module.security_group_lambda_stop_comfyui_instance.security_group_id]
  }
  environment = {
    # TODO: EC2作成時にコメントイン
    # EC2_INSTANCE_ID = module.ec2_comfyui.instance_id
    DYNAMODB_COMFYUI_LAST_ACCESS_AT_TABLE_NAME = module.dynamodb_comfyui_last_access_at.table_name
    IDLE_THRESHOLD_MS = 10 * 60 * 1000
  }
  inline_policy_json_documents = [
    {
      name = "LambdaStopComfyuiInstancePolicy"
      document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          # TODO: EC2作成時にコメントイン
          # # EC2
          # {
          #   Effect = "Allow"
          #   Action = ["ec2:DescribeInstances", "ec2:StopInstances"]
          #   Resource = [module.ec2_comfyui.arn]
          # },
          # DynamoDB
          {
            Effect = "Allow"
            Action = ["dynamodb:GetItem"]
            Resource = [module.dynamodb_comfyui_last_access_at.arn]
          }
        ]
      })
    }
  ]
}

# ==================================================
# S3 Bucket Notification
# ==================================================
module "s3_bucket_notification" {
  source    = "../../modules/s3_bucket_notification"
  bucket_id = module.s3_private.bucket_id
  lambda_functions = [
    {
      arn           = module.lambda_enforce_private_inputs_object_limit.lambda_function_arn
      events        = ["s3:ObjectCreated:*"]
      filter_prefix = "inputs/"
    },
    {
      arn           = module.lambda_save_generation_artifact_data.lambda_function_arn
      events        = ["s3:ObjectCreated:*"]
      filter_prefix = "outputs/"
    },
  ]
}

# ==================================================
# Scheduler
# ==================================================
module "scheduler_stop_comfyui_instance" {
  source              = "../../modules/scheduler"
  name                = "stop-comfyui-instance"
  target_arn          = module.lambda_stop_comfyui_instance.lambda_function_arn
  schedule_expression = "cron(0/5 * * * ? *)"
  timezone = "Asia/Tokyo"
  state = "DISABLED"
}

# ==================================================
# IAM User
# ==================================================
# backend
# TODO: API Gateway + LambdaでIAMロールを一時取得する方式に変更したい。
module "iam_user_backend" {
  source  = "../../modules/iam_user"
  name    = "backend"
  pgp_key = filebase64("${path.module}/.keys/gpg/public.gpg")
  inline_policy_json_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # SSM
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = [module.ssm_parameter_cloudfront_media_private_key.arn]
      },
      # S3
      {
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::${module.s3_private.bucket_id}",
          "arn:aws:s3:::${module.s3_private.bucket_id}/*"
        ]
      },
      # SQS
      {
        Effect   = "Allow"
        Action   = ["sqs:GetQueueUrl", "sqs:SendMessage"]
        Resource = [module.sqs_generation_job.arn]
      },
      # DynamoDB
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = [module.dynamodb_generation_job.arn]
      }
    ]
  })
}

# ローカルComfyUIを使用するテスト用
module "iam_user_comfyui_local" {
  source  = "../../modules/iam_user"
  name    = "comfyui-local"
  pgp_key = filebase64("${path.module}/.keys/gpg/public.gpg")
  inline_policy_json_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3
      {
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"]
        Resource = [
          "arn:aws:s3:::${module.s3_private.bucket_id}",
          "arn:aws:s3:::${module.s3_private.bucket_id}/*"
        ]
      },
    ]
  })
}

# output "iam_user_comfyui_local_encrypted_secret" {
#   value = module.iam_user_comfyui_local.secret_access_key
# }

# output "iam_user_backend_encrypted_secret" {
#   value = module.iam_user_backend.secret_access_key
# }
