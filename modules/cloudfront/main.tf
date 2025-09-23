# ==============================
# ACM
# ==============================
resource "aws_acm_certificate" "cdn" {
  domain_name       = "cdn.${var.root_domain}"
  validation_method = "DNS"
}

data "aws_route53_zone" "root" {
  name         = var.root_domain
  private_zone = false
}

resource "aws_route53_record" "cdn_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cdn.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  name    = each.value.name
  records = [each.value.record]
  ttl     = 300
  type    = each.value.type
  zone_id = data.aws_route53_zone.root.zone_id
}

resource "aws_acm_certificate_validation" "cdn" {
  certificate_arn         = aws_acm_certificate.cdn.arn
  validation_record_fqdns = [for record in aws_route53_record.cdn_cert_validation : record.fqdn]
}

# ==============================
# CloudFront CDN
# ==============================
resource "aws_cloudfront_public_key" "cdn" {
  name        = "${var.project}-${var.env}-cdn"
  encoded_key = var.cdn_public_key
}

resource "aws_cloudfront_key_group" "cdn" {
  name  = "${var.project}-${var.env}-cdn"
  items = [aws_cloudfront_public_key.cdn.id]
}

resource "aws_cloudfront_origin_access_control" "cdn" {
  name                              = "${var.project}-${var.env}-cdn"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "cdn" {
  name        = "${var.project}-${var.env}-cdn"
  min_ttl     = 0
  max_ttl     = 31536000
  default_ttl = 86400

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name              = var.cdn_bucket_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.cdn.id
    origin_id                = "cdn"
  }

  enabled         = true
  is_ipv6_enabled = true
  aliases         = ["cdn.${var.root_domain}"]

  default_cache_behavior {
    target_origin_id       = "cdn"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = aws_cloudfront_cache_policy.cdn.id
    viewer_protocol_policy = "redirect-to-https"

    trusted_key_groups = [aws_cloudfront_key_group.cdn.id]
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cdn.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["JP"]
    }
  }

  price_class = "PriceClass_200"
}

# ==============================
# S3 Bucket Policy
# ==============================
data "aws_iam_policy_document" "private" {
  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.private.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "private" {
  bucket = var.cdn_bucket_id
  policy = data.aws_iam_policy_document.private.json
}
