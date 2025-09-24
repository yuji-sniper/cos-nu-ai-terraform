variable "zone_id" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "cname" {
  type = object({
    ttl = number
    records = list(string)
  })
  default = null
}

variable "a" {
  type = object({
    alias_name = string
    alias_zone_id = string
  })
  default = null
}

variable "aaaa" {
  type = object({
    alias_name = string
    alias_zone_id = string
  })
  default = null
}
