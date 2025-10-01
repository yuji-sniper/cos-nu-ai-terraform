# ==================================================
# CloudWatchロググループ
# ==================================================
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.project}-${var.env}-${var.name}"
  retention_in_days = 30
}

# ==================================================
# IAMロール
# ==================================================
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${var.project}-${var.env}-${var.name}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.exec.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  for_each = toset(var.inline_policy_json_documents)
  role     = aws_iam_role.exec.name
  policy   = each.value
}

# ==================================================
# Lambda関数
# ==================================================
data "archive_file" "this" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = var.output_path
}

resource "aws_s3_object" "this" {
  bucket = var.s3_bucket_id
  key    = var.s3_key
  source = data.archive_file.this.output_path
  etag   = filemd5(data.archive_file.this.output_path)
}

resource "aws_lambda_function" "this" {
  function_name    = "${var.project}-${var.env}-${var.name}"
  role             = aws_iam_role.exec.arn
  handler          = var.handler
  runtime          = var.runtime
  s3_bucket        = var.s3_bucket_id
  s3_key           = var.s3_key
  source_code_hash = filebase64sha256(data.archive_file.this.output_path)
  timeout          = var.timeout
  memory_size      = var.memory_size

  logging_config {
    log_group  = aws_cloudwatch_log_group.this.name
    log_format = "JSON"
  }

  environment {
    variables = var.environment
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [1] : []
    content {
      subnet_ids         = var.vpc_config.subnet_ids
      security_group_ids = var.vpc_config.security_group_ids
    }
  }

  lifecycle {
    ignore_changes = [
      environment
    ]
  }
}

# ==================================================
# Lambda関数URL
# ==================================================
resource "aws_lambda_function_url" "this" {
  count              = var.enable_function_url ? 1 : 0
  function_name      = aws_lambda_function.this.function_name
  authorization_type = var.function_url_auth_type
  invoke_mode        = var.function_url_invoke_mode
  dynamic "cors" {
    for_each = var.function_url_cors != null ? [1] : []
    content {
      allow_credentials = var.function_url_cors.allow_credentials
      allow_origins     = var.function_url_cors.allow_origins
      allow_methods     = var.function_url_cors.allow_methods
      allow_headers     = var.function_url_cors.allow_headers
      expose_headers    = var.function_url_cors.expose_headers
      max_age           = var.function_url_cors.max_age
    }
  }
}

# ==================================================
# 関数URL呼び出し用のIAMユーザー（authorization_typeがAWS_IAMの場合のみ）
# ==================================================
locals {
  is_fn_url_auth_type_aws_iam = var.enable_function_url && var.function_url_auth_type == "AWS_IAM"
}

resource "aws_iam_user" "function_url_invoke" {
  count = local.is_fn_url_auth_type_aws_iam ? 1 : 0
  name  = "${var.project}-${var.env}-${var.name}-function-url-invoke"
}

data "aws_iam_policy_document" "function_url_invoke" {
  statement {
    actions   = ["lambda:InvokeFunctionUrl"]
    resources = [aws_lambda_function.this.arn]
    condition {
      test     = "StringEquals"
      variable = "lambda:FunctionUrlAuthType"
      values   = ["AWS_IAM"]
    }
  }
}

resource "aws_iam_user_policy" "function_url_invoke" {
  count  = local.is_fn_url_auth_type_aws_iam ? 1 : 0
  user   = aws_iam_user.function_url_invoke[0].name
  policy = data.aws_iam_policy_document.function_url_invoke.json
}
