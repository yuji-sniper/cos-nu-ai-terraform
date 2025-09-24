variable "project" {
  type        = string
}

variable "env" {
  type        = string
}

variable "region" {
  type        = string
}

variable "name" {
  type        = string
}

variable "zone_id" {
  type        = string
}

variable "domain_name" {
  type        = string
}

variable "s3_bucket_id" {
  type        = string
}

variable "trusted_public_key" {
  type        = string
  default = null
}
