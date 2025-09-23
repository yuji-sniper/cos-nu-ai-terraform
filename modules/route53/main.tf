data "aws_route53_zone" "root" {
  name         = var.root_domain
  private_zone = false
}

resource "aws_route53_record" "app_cname" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "app.${var.root_domain}"
  type    = "CNAME"
  ttl     = 300
  records = [var.vercel_cname_target]
}

resource "aws_route53_record" "cdn_a" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "cdn.${var.root_domain}"
  type    = "A"
  alias {
    name                   = var.cloudfront_cdn_distribution_domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cdn_aaaa" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "cdn.${var.root_domain}"
  type    = "AAAA"
  alias {
    name                   = var.cloudfront_cdn_distribution_domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}
