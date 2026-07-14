# PROVIDER
provider "aws" {
  region = "us-east-1"
}

# LOCALS
locals {
  s3_origin_id   = aws_s3_bucket.cactify-website-content.id
  cactify_domain = "${var.domain_config.subdomain}.${var.domain_config.main_domain}"
  hosted_zone_id = data.aws_route53_zone.cactify_domain.zone_id
}

# DATENQUELLEN
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_route53_zone" "cactify_domain" {
  name = var.domain_config.main_domain
}

# S3 BUCKET WEBSITE CONTENTS
# ----------------------------------------------------------------
# S3 Bucket 
resource "aws_s3_bucket" "cactify-website-content" {
  bucket           = format("cactify-website-content-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.current.name)
#  bucket_namespace = "account-regional"

  tags = {
    Name = var.s3_bucket_name
  }
}
# S3 Bucket Ownership Controls
resource "aws_s3_bucket_ownership_controls" "cactify-website-content" {
  bucket = aws_s3_bucket.cactify-website-content.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
# S3 Bucket ACL (Access Controll Lists)
resource "aws_s3_bucket_acl" "cactify-website-content" {
  depends_on = [aws_s3_bucket_ownership_controls.cactify-website-content]

  bucket = aws_s3_bucket.cactify-website-content.id
  acl    = "private"
}
# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "cactify-website-content" {
  bucket = aws_s3_bucket.cactify-website-content.id
  versioning_configuration {
    status = "Enabled"
  }
}
# S3 Cloudfront Origin Bucket Policy
resource "aws_s3_bucket_policy" "origin_bucket_policy" {
  bucket = aws_s3_bucket.cactify-website-content.id
  policy = data.aws_iam_policy_document.origin_bucket_policy.json
}
# Cloudfront Origin Access Control
resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "default-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
# S3 IAM Bucket-Policy (Cloudfront Access)
data "aws_iam_policy_document" "origin_bucket_policy" {
  statement {
    # falls buggy, versuche "AllowCloudFrontServicePrincipalReadWrite"
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.cactify-website-content.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cactify_distribution.arn]
    }
  }
}

# ACM (Certificate Manager) + DNS-Validierung
# ----------------------------------------------------------------
resource "aws_acm_certificate" "cactify_cf" {
  provider                  = aws
  domain_name               = local.cactify_domain
  subject_alternative_names = ["www.${local.cactify_domain}"]
  validation_method         = "DNS"
  # validation_option {
  #   domain_name       = "cactify.florianjanssens.de"
  #   validation_domain = "florianjanssens.de"
  # }
}
# DNS-Einträge für Certificate Validierung
resource "aws_route53_record" "acm_records" {
  for_each = {
    for dvo in aws_acm_certificate.cactify_cf.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.cactify_domain.zone_id
}
# ACM Certificate Validation
resource "aws_acm_certificate_validation" "cactify_cf" {
  certificate_arn         = aws_acm_certificate.cactify_cf.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_records : record.fqdn]
}

# ----------------------------------------------------------------
# CLOUDFRONT DISTRIBUTION
# ----------------------------------------------------------------
resource "aws_cloudfront_distribution" "cactify_distribution" {
  origin {
    domain_name              = aws_s3_bucket.cactify-website-content.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Cloudfront Distribution for cactify.florianjanssens.de"
  default_root_object = "index.html"

  aliases = ["${local.cactify_domain}", "www.${local.cactify_domain}"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  tags = {
    Environment = "production"

  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.cactify_cf.certificate_arn
    ssl_support_method  = "sni-only"
  }
}
# ----------------------------------------------------------------
# Cloudfront Distribution Ende
# ----------------------------------------------------------------

# DNS-Einträge für CloudFront-Distribution (aliases)
resource "aws_route53_record" "cloudfront" {
  for_each = toset(aws_cloudfront_distribution.cactify_distribution.aliases)
  zone_id  = data.aws_route53_zone.cactify_domain.zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.cactify_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.cactify_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
# AAAA-Eintrag?
# AWS-SES Einträge? TXT, MX, CNAMES?
# ----------------------------------------------------------------

# LOGGING
# ----------------------------------------------------------------
# 1. CloudFront Logging

# Cloudwatch Log Delivery Source
resource "aws_cloudwatch_log_delivery_source" "cactify_distribution" {
  # region = "us-east-1"

  name         = "cactify_distribution"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.cactify_distribution.arn
}
# S3 Log Bucket
resource "aws_s3_bucket" "cactify-logging" {
  bucket        = "cactify-logging-bucket"
  force_destroy = true
}
# Log Delivery Destination
resource "aws_cloudwatch_log_delivery_destination" "cactify_distribution" {
#  region = "us-east-1"

  name          = "s3-destination"
  output_format = "parquet"

  delivery_destination_configuration {
    destination_resource_arn = "${aws_s3_bucket.cactify-logging.arn}/prefix"
  }
}
# Log Delivery
resource "aws_cloudwatch_log_delivery" "cactify_distribution" {
  # region = "us-east-1"

  delivery_source_name     = aws_cloudwatch_log_delivery_source.cactify_distribution.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cactify_distribution.arn

  s3_delivery_configuration {
    # suffix_path = "/123456678910/{DistributionId}/{yyyy}/{MM}/{dd}/{HH}"
    suffix_path = format("/%s/%s/{yyyy}/{MM}/{dd}/{HH}", data.aws_caller_identity.current.account_id, aws_cloudfront_distribution.cactify_distribution.id)
  }
}
# 2. Logging for Lambda
# S3 BUCKET FOR LOGGING (Lambda)


# API-GATEWAY


# LAMBDA 


# AWS SES


# IAM ROLE MODUL


# IAM ROLE LAMBDA-SES


# Budget 
# Monitoring (Cloudwatch)
