# target_arnのリソースとactionをマッピング
locals {
  target_service = try(element(split(":", var.target_arn), 2), "")
  service_actions_map = {
    lambda = ["lambda:InvokeFunction"]
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name = "${var.project}-${var.env}-scheduler-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    actions = lookup(local.service_actions_map, local.target_service, [])
    resources = [var.target_arn]
  }
}

resource "aws_iam_policy" "scheduler" {
  name = "${var.project}-${var.env}-scheduler-${var.name}"
  policy = data.aws_iam_policy_document.scheduler.json
}

resource "aws_iam_role_policy_attachment" "scheduler" {
  role = aws_iam_role.scheduler.name
  policy_arn = aws_iam_policy.scheduler.arn
}

resource "aws_scheduler_schedule" "this" {
  name = "${var.project}-${var.env}-${var.name}"
  schedule_expression = var.schedule_expression
  schedule_expression_timezone = var.timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn = var.target_arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
