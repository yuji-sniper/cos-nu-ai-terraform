variable "project" {
  type = string
}

variable "env" {
  type = string
}

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
