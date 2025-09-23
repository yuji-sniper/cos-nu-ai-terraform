variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "root_domain" {
  type = string
}

variable "comfyui_instance_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "status_dynamo_db_table_name" {
  type = string
}

variable "idle_timeout_minutes" {
  type = number
}

variable "comfyui_bff" {
  type = object({
    source_dir = string
    output_path = string
  })
}

variable "stop_comfyui" {
  type = object({
    source_dir = string
    output_path = string
  })
}
