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
  type = list(string)
  default = []
}

variable "inline_policy_json_documents" {
  type = list(string)
  default = []
}

variable "source_dir" {
  type = string
}

variable "output_path" {
  type = string
}

variable "s3_bucket_id" {
  type = string
}

variable "s3_key" {
  type = string
}

variable "handler" {
  type = string
}

variable "runtime" {
  type = string
}

variable "timeout" {
  type = number
  default = 300
}

variable "memory_size" {
  type = number
  default = 128
}

variable "environment" {
  type = map(string)
  default = {}
}

variable "vpc_config" {
  type = object({
    subnet_ids = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "enable_function_url" {
  type = bool
  default = false
}

variable "function_url_auth_type" {
  type = string
  default = "NONE"
}

variable "function_url_invoke_mode" {
  type = string
  default = "BUFFERED"
}

variable "function_url_cors" {
  type = object({
    allow_credentials = bool
    allow_origins = list(string)
    allow_methods = list(string)
    allow_headers = list(string)
    expose_headers = list(string)
    max_age = number
  })
  default = null
}
