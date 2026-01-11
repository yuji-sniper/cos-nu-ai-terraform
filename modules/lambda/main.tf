# ==================================================
# CloudWatchロググループ
# ==================================================
resource "aws_cloudwatch_log_group" "this" {
  name              = "/lambda/${var.name}"
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
  name               = "${var.name}-lambda-assume"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC内にLambdaを配置する場合に必要
resource "aws_iam_role_policy_attachment" "vpc_access" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "managed" {
  count      = length(var.managed_policy_arns)
  role       = aws_iam_role.exec.name
  policy_arn = var.managed_policy_arns[count.index]
}

resource "aws_iam_role_policy" "inline" {
  count  = length(var.inline_policy_json_documents)
  name   = var.inline_policy_json_documents[count.index].name
  policy = var.inline_policy_json_documents[count.index].document
  role   = aws_iam_role.exec.name
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
  function_name    = var.name
  role             = aws_iam_role.exec.arn
  handler          = var.handler
  runtime          = var.runtime
  s3_bucket        = var.s3_bucket_id
  s3_key           = var.s3_key
  source_code_hash = filebase64sha256(data.archive_file.this.output_path)
  timeout          = var.timeout
  memory_size      = var.memory_size
  publish          = var.publish
  reserved_concurrent_executions = var.reserved_concurrent_executions

  layers = var.layer_arns

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

  depends_on = [
    aws_s3_object.this,
    aws_iam_role_policy_attachment.basic,
    aws_iam_role_policy_attachment.vpc_access,
    aws_iam_role_policy_attachment.managed,
    aws_iam_role_policy.inline
  ]
}

# ==================================================
# Lambda permission
# ==================================================
resource "aws_lambda_permission" "this" {
  count = var.permission != null ? 1 : 0
  statement_id  = var.permission.statement_id
  action        = var.permission.action
  function_name = aws_lambda_function.this.function_name
  principal     = var.permission.principal
  source_arn    = var.permission.source_arn
}

# ==================================================
# Lambda event source mapping
# ==================================================
resource "aws_lambda_event_source_mapping" "this" {
  count              = var.event_source_mapping != null ? 1 : 0
  event_source_arn   = var.event_source_mapping.event_source_arn
  function_name      = aws_lambda_function.this.function_name
  batch_size         = var.event_source_mapping.batch_size
  starting_position  = try(var.event_source_mapping.starting_position, null)

  dynamic "scaling_config" {
    for_each = var.event_source_mapping.scaling_config != null ? [1] : []
    content {
      maximum_concurrency = var.event_source_mapping.scaling_config.maximum_concurrency
    }
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
