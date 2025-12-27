variable "name" {
  type = string
}

variable "enable_versioning" {
  type    = bool
  default = false
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "cors_rules" {
  type = list(object({
    allowed_origins = list(string)
    allowed_methods = list(string)
    allowed_headers = optional(list(string))
    expose_headers = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = null
}
