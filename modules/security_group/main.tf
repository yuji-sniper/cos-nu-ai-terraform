resource "aws_security_group" "this" {
  name   = var.name
  vpc_id = var.vpc_id
}
