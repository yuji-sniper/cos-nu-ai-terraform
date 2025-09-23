data "aws_caller_identity" "current" {}

# S3バケット（Lambda関数のソースコードを保存）
resource "aws_s3_bucket" "lambda_functions" {
  bucket = "${var.project}-${var.env}-lambda-functions"
  region = var.region
  force_destroy = true
}

# IAMロール（Lambda Assume Role）
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ==================================================
# Lambda(ComfyUI BFF)
# ==================================================
# IAMロール
resource "aws_iam_role" "lambda_comfyui_bff" {
  name = "lambda_comfyui_bff"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_comfyui_bff_basic" {
  role = aws_iam_role.lambda_comfyui_bff.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_comfyui_bff" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:StartInstances"
    ]
    resources = ["arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/${var.comfyui_instance_id}"]
  }
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem"
    ]
    resources = ["arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.status_dynamo_db_table_name}"]
  }
}

resource "aws_iam_role_policy" "lambda_comfyui_bff" {
  role = aws_iam_role.lambda_comfyui_bff.name
  policy = data.aws_iam_policy_document.lambda_comfyui_bff.json
}

# Lambda関数
data "archive_file" "lambda_comfyui_bff" {
  type = "zip"
  source_dir = var.comfyui_bff.source_dir
  output_path = var.comfyui_bff.output_path
}

resource "aws_s3_object" "lambda_comfyui_bff" {
  bucket = aws_s3_bucket.lambda_functions.bucket
  key = "comfyui_bff.zip"
  source = data.archive_file.lambda_comfyui_bff.output_path
  etag = filemd5(data.archive_file.lambda_comfyui_bff.output_path)
}

resource "aws_lambda_function" "lambda_comfyui_bff" {
  function_name = "${var.project}-${var.env}-comfyui-bff"
  role = aws_iam_role.lambda_comfyui_bff.arn
  handler = "lambda_function.handler"
  runtime = "nodejs22.x"
  s3_bucket = aws_s3_bucket.lambda_functions.bucket
  s3_key = "comfyui_bff.zip"
  source_code_hash = filebase64sha256(data.archive_file.lambda_comfyui_bff.output_path)
  timeout = 300
  memory_size = 128

  vpc_config {
    subnet_ids = var.private_subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      COMFYUI_INSTANCE_ID = var.comfyui_instance_id
      COMFYUI_STATUS_DYNAMO_DB_TABLE_NAME = var.status_dynamo_db_table_name
    }
  }
}

resource "aws_lambda_function_url" "lambda_comfyui_bff" {
  function_name = aws_lambda_function.lambda_comfyui_bff.function_name
  authorization_type = "AWS_IAM"
  invoke_mode = "BUFFERED"

  cors {
    allow_origins = ["https://app.${var.root_domain}"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["*"]
    expose_headers = ["*"]
    max_age = 300
  }
}

# IAMユーザー(Function URL 呼び出し用)
resource "aws_iam_user" "comfyui_bff_lambda_function_url_invoker" {
  name = "${var.project}-${var.env}-comfyui-bff-lambda-function-url-invoker"
}

data "aws_iam_policy_document" "comfyui_bff_lambda_function_url_invoker" {
  statement {
    actions = ["lambda:InvokeFunctionUrl"]
    resources = [aws_lambda_function.lambda_comfyui_bff.arn]
    condition {
      test = "StringEquals"
      variable = "lambda:FunctionUrlAuthType"
      values = ["AWS_IAM"]
    }
  }
}

resource "aws_iam_user_policy" "lambda_comfyui_bff_invoker_policy" {
  user = aws_iam_user.comfyui_bff_lambda_function_url_invoker.name
  policy = data.aws_iam_policy_document.comfyui_bff_lambda_function_url_invoker.json
}

# ==================================================
# Lambda(Stop ComfyUI)
# ==================================================
# IAMロール
resource "aws_iam_role" "lambda_stop_comfyui" {
  name = "lambda_stop_comfyui"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_stop_comfyui_basic" {
  role = aws_iam_role.lambda_stop_comfyui.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_stop_comfyui" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:StopInstances"
    ]
    resources = ["arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/${var.comfyui_instance_id}"]
  }
  statement {
    actions = ["dynamodb:GetItem"]
    resources = ["arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.status_dynamo_db_table_name}"]
  }
}

resource "aws_iam_policy" "lambda_stop_comfyui" {
  name = "lambda_stop_comfyui"
  policy = data.aws_iam_policy_document.lambda_stop_comfyui.json
}

resource "aws_iam_role_policy_attachment" "lambda_stop_comfyui" {
  role = aws_iam_role.lambda_stop_comfyui.name
  policy_arn = aws_iam_policy.lambda_stop_comfyui.arn
}

# Lambda関数
data "archive_file" "lambda_stop_comfyui" {
  type = "zip"
  source_dir = var.stop_comfyui.source_dir
  output_path = var.stop_comfyui.output_path
}

resource "aws_s3_object" "lambda_stop_comfyui" {
  bucket = aws_s3_bucket.lambda_functions.bucket
  key = "stop_comfyui.zip"
  source = data.archive_file.lambda_stop_comfyui.output_path
  etag = filemd5(data.archive_file.lambda_stop_comfyui.output_path)
}

resource "aws_lambda_function" "lambda_stop_comfyui" {
  function_name = "${var.project}-${var.env}-stop-comfyui"
  role = aws_iam_role.lambda_stop_comfyui.arn
  handler = "lambda_function.handler"
  runtime = "nodejs22.x"
  s3_bucket = aws_s3_bucket.lambda_functions.bucket
  s3_key = "stop_comfyui.zip"
  source_code_hash = filebase64sha256(data.archive_file.lambda_stop_comfyui.output_path)
  timeout = 300
  memory_size = 128

  vpc_config {
    subnet_ids = var.private_subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      COMFYUI_INSTANCE_ID = var.comfyui_instance_id
      COMFYUI_STATUS_DYNAMO_DB_TABLE_NAME = var.status_dynamo_db_table_name
    }
  }
}

# TODO: EventBridgeモジュールに書かないと循環参照になりそう
resource "aws_lambda_permission" "lambda_stop_comfyui" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_stop_comfyui.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.stop_comfyui.arn
}
