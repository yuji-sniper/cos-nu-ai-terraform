resource "aws_vpc_security_group_egress_rule" "egress_to_prefix_list" {
  count = length(var.egress_to_prefix_list)
  security_group_id = var.security_group_id
  description       = var.egress_to_prefix_list[count.index].description
  prefix_list_id    = var.egress_to_prefix_list[count.index].prefix_list_id
  from_port         = var.egress_to_prefix_list[count.index].from_port
  to_port           = var.egress_to_prefix_list[count.index].to_port
  ip_protocol       = var.egress_to_prefix_list[count.index].ip_protocol

}

resource "aws_vpc_security_group_egress_rule" "egress_to_sg" {
  count = length(var.egress_to_sg)
  security_group_id            = var.security_group_id
  description                  = var.egress_to_sg[count.index].description
  referenced_security_group_id = var.egress_to_sg[count.index].referenced_security_group_id
  from_port                    = var.egress_to_sg[count.index].from_port
  to_port                      = var.egress_to_sg[count.index].to_port
  ip_protocol                  = var.egress_to_sg[count.index].ip_protocol
}

resource "aws_vpc_security_group_ingress_rule" "ingress_from_sg" {
  count = length(var.ingress_from_sg)
  security_group_id            = var.security_group_id
  description                  = var.ingress_from_sg[count.index].description
  referenced_security_group_id = var.ingress_from_sg[count.index].referenced_security_group_id
  from_port                    = var.ingress_from_sg[count.index].from_port
  to_port                      = var.ingress_from_sg[count.index].to_port
  ip_protocol                  = var.ingress_from_sg[count.index].ip_protocol
}
