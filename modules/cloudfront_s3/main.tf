# ==============================
# ACM
# ==============================
resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = "DNS"
}

resource "aws_route53_record" "this" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  name    = each.value.name
  records = [each.value.record]
  ttl     = 300
  type    = each.value.type
  zone_id = var.zone_id
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.this : record.fqdn]
}

# ==============================
# キー
# ==============================
resource "aws_cloudfront_public_key" "this" {
  count       = var.trusted_public_key != null ? 1 : 0
  name        = "${var.project}-${var.env}-${var.name}"
  encoded_key = var.trusted_public_key
}

resource "aws_cloudfront_key_group" "this" {
  count = var.trusted_public_key != null ? 1 : 0
  name  = "${var.project}-${var.env}-${var.name}"
  items = [aws_cloudfront_public_key.this.id]
}

# ==============================
# OAC
# ==============================
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.project}-${var.env}-${var.name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ==============================
# Cache Policy
# ==============================
resource "aws_cloudfront_cache_policy" "this" {
  name        = "${var.project}-${var.env}-${var.name}"
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

# ==============================
# CloudFront Distribution
# ==============================
resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name              = "${var.s3_bucket_id}.s3.${var.region}.amazonaws.com"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_id                = "${var.project}-${var.env}-${var.name}"
  }

  enabled         = true
  is_ipv6_enabled = true
  aliases         = [var.domain_name]

  default_cache_behavior {
    target_origin_id       = "${var.project}-${var.env}-${var.name}"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = aws_cloudfront_cache_policy.this.id
    viewer_protocol_policy = "redirect-to-https"

    trusted_key_groups = var.trusted_public_key != null ? [aws_cloudfront_key_group.this.id] : []
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.this.arn
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

  depends_on = [aws_acm_certificate_validation.this]
}

# ==============================
# S3 Bucket Policy
# ==============================
data "aws_iam_policy_document" "this" {
  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.s3_bucket_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = var.s3_bucket_id
  policy = data.aws_iam_policy_document.this.json
}

# ==============================
# Route53 Alias Record
# ==============================
locals {
  record_types = ["A", "AAAA"]
}

resource "aws_route53_record" "this" {
  for_each = toset(local.record_types)
  zone_id  = var.zone_id
  name     = var.domain_name
  type     = each.value
  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
