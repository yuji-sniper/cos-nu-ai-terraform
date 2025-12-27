resource "aws_route53_record" "this" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = var.type
  ttl     = var.ttl
  records = var.records
  dynamic "alias" {
    for_each = var.alias != null ? [1] : []
    content {
      name                   = var.alias.name
      zone_id                = var.alias.zone_id
      evaluate_target_health = var.alias.evaluate_target_health
    }
  }
}

