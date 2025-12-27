variable "zone_id" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "type" {
  type = string
  default = "A"
  validation {
    condition     = contains(["A", "AAAA", "CNAME"], var.type)
    error_message = "Invalid type. Must be one of: A, AAAA, CNAME."
  }
}

variable "ttl" {
  type = number
  default = 300
}

variable "records" {
  type = list(string)
  default = []
}

variable "alias" {
  type = object({
    name    = string
    zone_id = string
    evaluate_target_health = bool
  })
  default = null
}
