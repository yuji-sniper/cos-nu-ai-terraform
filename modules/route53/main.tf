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
