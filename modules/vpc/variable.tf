variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "private_subnet_availability_zones" {
  type    = list(string)
  default = []
}

variable "public_subnet_availability_zones" {
  type    = list(string)
  default = []
}
