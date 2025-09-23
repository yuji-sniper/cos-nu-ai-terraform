resource "aws_vpc_security_group_egress_rule" "egress_to_prefix_list" {
  for_each = tomap(var.egress_to_prefix_list)
  security_group_id = var.security_group_id
  description       = each.value.description
  prefix_list_id         = each.value.prefix_list_id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
  
}

resource "aws_vpc_security_group_egress_rule" "egress_to_sg" {
  for_each = tomap(var.egress_to_sg)
  security_group_id = var.security_group_id
  description       = each.value.description
  referenced_security_group_id = each.value.referenced_security_group_id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
}

resource "aws_vpc_security_group_ingress_rule" "ingress_from_sg" {
  for_each = tomap(var.ingress_from_sg)
  security_group_id = var.security_group_id
  description       = each.value.description
  referenced_security_group_id = each.value.referenced_security_group_id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
}
