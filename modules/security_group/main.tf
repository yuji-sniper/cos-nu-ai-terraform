resource "aws_security_group" "this" {
  name   = "${var.project}-${var.env}-${var.name}"
  vpc_id = var.vpc_id
}
