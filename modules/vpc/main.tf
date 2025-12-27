# ==============================
# VPC
# ==============================
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = var.name
  }
}

# ==============================
# Subnet(Private)
# ==============================
locals {
  private_count = length(var.private_subnet_availability_zones)
}

resource "aws_subnet" "private" {
  count             = local.private_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = var.private_subnet_availability_zones[count.index]
  tags = {
    Name = "${var.name}-private-${var.private_subnet_availability_zones[count.index]}"
  }
}

resource "aws_route_table" "private" {
  count  = local.private_count
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route_table_association" "private" {
  count          = local.private_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ==============================
# Subnet(Public)
# ==============================
locals {
  public_count = length(var.public_subnet_availability_zones)
}

resource "aws_internet_gateway" "this" {
  count  = local.public_count != 0 ? 1 : 0
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_subnet" "public" {
  count             = local.public_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, local.private_count + count.index)
  availability_zone = var.public_subnet_availability_zones[count.index]
  tags = {
    Name = "${var.name}-public-${var.public_subnet_availability_zones[count.index]}"
  }
}

resource "aws_route_table" "public" {
  count  = local.public_count
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route" "public_default" {
  count                  = local.public_count != 0 ? 1 : 0
  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[count.index].id
}

resource "aws_route_table_association" "public" {
  count          = local.public_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}
