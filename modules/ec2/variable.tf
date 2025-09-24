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

variable "inline_policy_json_document" {
  type = string
  default = null
}

variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "associate_public_ip_address" {
  type = bool
}

variable "root_block_device" {
  type = object({
    volume_size = number
    volume_type = string
    iops = number
    encrypted = bool
    delete_on_termination = bool
  })
}
