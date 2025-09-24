resource "aws_route53_record" "cname" {
  count = var.cname != null ? 1 : 0
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "CNAME"
  ttl     = var.cname.ttl
  records = var.cname.records
}

resource "aws_route53_record" "a" {
  count = var.a != null ? 1 : 0
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = var.a.alias_name
    zone_id                = var.a.alias_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa" {
  count = var.aaaa != null ? 1 : 0
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "AAAA"
  alias {
    name                   = var.aaaa.alias_name
    zone_id                = var.aaaa.alias_zone_id
    evaluate_target_health = false
  }
}
