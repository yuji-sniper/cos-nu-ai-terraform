variable "name" {
  type = string
}

variable "target_arn" {
  type = string
}

variable "schedule_expression" {
  type = string
}

variable "timezone" {
  type    = string
  default = "Asia/Tokyo"
}

variable "state" {
  type    = string
  default = "ENABLED"
}
