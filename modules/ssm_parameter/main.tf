terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

resource "aws_ssm_parameter" "this" {
  name  = var.name
  type  = var.type
  value = var.value

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
