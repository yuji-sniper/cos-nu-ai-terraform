variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "name" {
  type = string
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}

variable "inline_policy_json_document" {
  type    = string
  default = null
}
