resource "aws_default_vpc" "this" {}

resource "aws_default_subnet" "this" {
  availability_zone = var.availability_zone
}
