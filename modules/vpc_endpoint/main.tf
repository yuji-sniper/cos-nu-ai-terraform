# ==============================
# VPC Endpoint(Gateway)
# ==============================
resource "aws_vpc_endpoint" "gateway" {
  count             = length(var.gateway)
  vpc_id            = var.vpc_id
  service_name      = var.gateway[count.index].service_name
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.gateway[count.index].route_table_ids
  policy            = var.gateway[count.index].policy
  tags = {
    Name = "${var.vpc_name}-${element(split(".", var.gateway[count.index].service_name), -1)}-gateway"
  }
}

# ==============================
# VPC Endpoint(Interface)
# ==============================
resource "aws_vpc_endpoint" "interface" {
  count               = length(var.interface)
  vpc_id              = var.vpc_id
  service_name        = var.interface[count.index].service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.interface[count.index].subnet_ids
  security_group_ids  = var.interface[count.index].security_group_ids
  private_dns_enabled = true
  tags = {
    Name = "${var.vpc_name}-${element(split(".", var.interface[count.index].service_name), -1)}-interface"
  }
}
