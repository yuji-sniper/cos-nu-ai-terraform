variable "name" {
  type = string
}

variable "billing_mode" {
  type    = string
  default = "PAY_PER_REQUEST"
}

variable "pk" {
  type = object({
    name = string
    type = string
  })
  description = "type = S|N|B"
}

variable "ttl" {
  type = object({
    attribute_name = string
  })
  default = null
}

variable "point_in_time_recovery" {
  type    = bool
  default = false
}

variable "item" {
  type    = string
  default = null
}
