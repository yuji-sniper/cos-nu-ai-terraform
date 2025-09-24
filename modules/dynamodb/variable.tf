variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "name" {
  type = string
}

variable "billing_mode" {
  type = string
  default = "PAY_PER_REQUEST"
}

variable "pk" {
  type = object({
    name = string
    type = string
  })
  description = "type = S|N|B"
}

variable "point_in_time_recovery" {
  type = bool
  default = false
}
