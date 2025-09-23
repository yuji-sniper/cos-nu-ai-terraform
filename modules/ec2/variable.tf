variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "s3_private_bucket_arn" {
  type = string
}

variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "comfyui_security_group_ids" {
  type = list(string)
}

variable "ebs_volume_size" {
  type = number
}
