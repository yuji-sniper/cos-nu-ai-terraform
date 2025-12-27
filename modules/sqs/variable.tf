variable "name" {
  type = string
}

variable "visibility_timeout_seconds" {
  type = number
}

variable "message_retention_seconds" {
  type = number
}

variable "max_retry_count" {
  type = number
  default = 3
}

variable "deadletter_retention_days" {
  type = number
  default = 14
}
