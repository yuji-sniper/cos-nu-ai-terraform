variable "name" {
  type = string
}

variable "pgp_key" {
  type = string
  default = null
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}

variable "inline_policy_json_document" {
  type    = string
  default = null
}
