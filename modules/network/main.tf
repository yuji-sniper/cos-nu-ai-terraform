resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "${var.project}-${var.env}"
  }
}

resource "aws_subnet" "private" {
  count = length(var.availability_zones)
  vpc_id = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.project}-${var.env}-private-${var.availability_zones[count.index]}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project}-${var.env}-private"
  }
}

resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# インターネットを経由せずにS3(VPC外のリソース)にアクセスできるようにする
resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.private.id]
  tags = {
    Name = "${var.project}-${var.env}-s3"
  }
}

# セッションマネージャーからインターネットを経由せずにEC2にアクセスできるようにする
locals {
  interface_services = [
    "ssm",
    "ssmmessages",
  ]
}

resource "aws_security_group" "vpc_endpoint" {
  name = "${var.project}-${var.env}-vpc-endpoint"
  vpc_id = aws_vpc.main.id
  ingress = {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  egress = {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_services
  vpc_id = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type = "Interface"
  security_group_ids = [aws_security_group.vpc_endpoint.id]
  subnet_ids = aws_subnet.private[*].id
  tags = {
    Name = "${var.project}-${var.env}-${each.value}"
  }
}
