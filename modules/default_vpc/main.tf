resource "aws_default_vpc" "this" {}

resource "aws_default_subnet" "this" {
  count = length(var.availability_zones)
  availability_zone = var.availability_zones[count.index]
}
