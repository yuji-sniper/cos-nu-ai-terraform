data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "stop_comfyui" {
  name = "${var.project}-${var.env}-stop-comfyui"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

data "aws_iam_policy_document" "stop_comfyui" {
  statement {
    actions = ["lambda:InvokeFunction"]
    resources = ["arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${var.stop_comfyui_lambda_function_name}"]
  }
}

resource "aws_iam_policy" "stop_comfyui" {
  name = "${var.project}-${var.env}-scheduler-stop-comfyui"
  policy = data.aws_iam_policy_document.stop_comfyui.json
}

resource "aws_iam_role_policy_attachment" "stop_comfyui" {
  role = aws_iam_role.stop_comfyui.name
  policy_arn = aws_iam_policy.stop_comfyui.arn
}

resource "aws_scheduler_schedule" "stop_comfyui" {
  name = "${var.project}-${var.env}-stop-comfyui"
  schedule_expression = "cron(0/5 * * * ? *)"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn = "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${var.stop_comfyui_lambda_function_name}"
    role_arn = aws_iam_role.stop_comfyui.arn
  }
}

resource "aws_lambda_permission" "stop_comfyui" {
  action = "lambda:InvokeFunction"
  function_name = var.stop_comfyui_lambda_function_name
  principal = "scheduler.amazonaws.com"
  source_arn = aws_scheduler_schedule.stop_comfyui.arn
}
