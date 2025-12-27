variable "bucket_id" {
  type = string
}

variable "lambda_functions" {
  type = list(object({
    arn = string
    events = list(string)
    filter_prefix = optional(string)
    filter_suffix = optional(string)
  }))
}
