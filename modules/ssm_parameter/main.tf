resource "aws_ssm_parameter" "this" {
  name  = "/${var.project}/${var.env}/${var.name}"
  type  = var.type
  value = var.value
}
