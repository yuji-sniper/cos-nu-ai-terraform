variable "security_group_id" {
  type = string
}

variable "egress_to_prefix_list" {
  type = list(object({
    description = string
    prefix_list_id = string
    from_port = number
    to_port = number
    ip_protocol = string
  }))
  default = []
}
variable "egress_to_sg" {
  type = list(object({
    description = string
    referenced_security_group_id = string
    from_port = number
    to_port = number
    ip_protocol = string
  }))
  default = []
}

variable "ingress_from_sg" {
  type = list(object({
    description = string
    referenced_security_group_id = string
    from_port = number
    to_port = number
    ip_protocol = string
  }))
  default = []
}
