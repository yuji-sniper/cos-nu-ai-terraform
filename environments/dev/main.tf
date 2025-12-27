data "aws_caller_identity" "current" {}

data "aws_region" "apne1" {
  provider = aws.apne1
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
# 生成ジョブ
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
  # TODO: VPC内に配置する
  # vpc_config = {}
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
