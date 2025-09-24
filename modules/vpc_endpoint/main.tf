# ==============================
# VPC Endpoint(Gateway)
# ==============================
resource "aws_vpc_endpoint" "gateway" {
  for_each          = tomap(var.gateway)
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.${each.value.service_name}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = each.value.route_table_ids
  policy            = each.value.policy
}

# ==============================
# VPC Endpoint(Interface)
# ==============================
resource "aws_vpc_endpoint" "interface" {
  for_each            = tomap(var.interface)
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value.service_name}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = each.value.subnet_ids
  security_group_ids  = each.value.security_group_ids
  private_dns_enabled = true
}
