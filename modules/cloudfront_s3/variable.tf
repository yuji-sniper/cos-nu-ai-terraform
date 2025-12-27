variable "name" {
  type = string
}

variable "zone_id" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "s3_bucket_id" {
  type = string
}

variable "s3_bucket_domain_name" {
  type = string
}

variable "encoded_public_key" {
  type    = string
  default = null
}
