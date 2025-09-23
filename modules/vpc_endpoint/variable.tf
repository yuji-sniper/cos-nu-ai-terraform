variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "gateway" {
  type = list(object({
    service_name = string
    route_table_ids = list(string)
    policy = string
  }))
  default = []
}

variable "interface" {
  type = list(object({
    service_name = string
    subnet_ids = list(string)
    security_group_ids = list(string)
  }))
  default = []
}
