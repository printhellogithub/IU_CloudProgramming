provider "aws" {
  region = "us-east-1"
}

# S3 BUCKET WEBSITE CONTENTS
# deprecated version

# module "s3_bucket" {
#   source = "terraform-aws-modules/s3-bucket/aws"

#   bucket = "cactify-website-content"
#   acl    = "private"

#   control_object_ownership = true
#   object_ownership         = "ObjectWriter"

#   versioning = {
#     enabled = true
#   }

#   tags = {
#     Name = var.s3_bucket_name
#   }
# }

# ----------------------------------------------------------------
# S3 BUCKET WEBSITE CONTENTS
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "cactify-website-content" {
  bucket           = format("cactify-website-content-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  bucket_namespace = "account-regional"

  tags = {
    Name = var.s3_bucket_name
  }
}

resource "aws_s3_bucket_ownership_controls" "cactify-website-content" {
  bucket = aws_s3_bucket.cactify-website-content.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cactify-website-content" {
  depends_on = [aws_s3_bucket_ownership_controls.cactify-website-content]

  bucket = aws_s3_bucket.cactify-website-content.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "cactify-website-content" {
  bucket = aws_s3_bucket.cactify-website-content.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ----------------------------------------------------------------
# S3 Bucket-Policy (Cloudfront Access)
data "aws_iam_policy_document" "PolicyForCloudFrontPrivateContent" {
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

# ----------------------------------------------------------------
# S3 Cloudfront Origin Bucket Policy
resource "aws_s3_bucket_policy" "origin_bucket_policy" {
  bucket = aws_s3_bucket.cactify-website-content
  policy = data.aws_iam_policy_document.origin_bucket_policy.json
}

locals {
  s3_origin_id   = aws_s3_bucket.cactify-website-content.id
  cactify_domain = "cactify.florianjanssens.com"
  main_domain    = "florianjanssens.de"
}

data "aws_acm_certificate" "florianjanssens_domain" {
  region   = "us-east-1"
  domain   = "*.${local.main_domain}"
  statuses = ["ISSUED"]
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "default-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
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

  price_class = "PriceClass_ALL"

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
    acm_certificate_arn = data.aws_acm_certificate.main_domain.arn
    ssl_support_method  = "sni-only"
  }
}

# Create Route53 records for the CloudFront distribution aliases
data "aws_route53_zone" "cactify_domain" {
  name = local.main_domain
}

resource "aws_route53_record" "cloudfront" {
  for_each = aws_cloudfront_distribution.cactify_distribution.aliases
  zone_id  = data.aws_route53_zone.local.main_domain.zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.cactify_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.cactify_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
# ----------------------------------------------------------------
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# S3 BUCKET FOR LOGGING (Cloudfront)

resource "aws_cloudwatch_log_delivery_source" "cactify_distribution" {
  region = "us-east-1"

  name         = "cactify_distribution"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.cactify_distribution.arn
}

resource "aws_s3_bucket" "cactify-logging" {
  bucket        = "cactify-logging-bucket"
  force_destroy = true
}

resource "aws_cloudwatch_log_delivery_destination" "cactify_distribution" {
  region = "us-east-1"

  name          = "s3-destination"
  output_format = "parquet"

  delivery_destination_configuration {
    destination_resource_arn = "${aws_s3_bucket.cactify-logging.arn}/prefix"
  }
}

resource "aws_cloudwatch_log_delivery" "cactify_distribution" {
  region = "us-east-1"

  delivery_source_name     = aws_cloudwatch_log_delivery_source.cactify_distribution.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cactify_distribution.arn

  s3_delivery_configuration {
    # suffix_path = "/123456678910/{DistributionId}/{yyyy}/{MM}/{dd}/{HH}"
    suffix_path = format("/%s/%s/{yyyy}/{MM}/{dd}/{HH}", data.aws_caller_identity.current.account_id, aws_cloudfront_distribution.cactify_distribution.id)
  }
}

# resource "aws_s3_bucket" "logging" {
#   bucket = "cactify-logging-bucket"
# }

# data "aws_iam_policy_document" "logging_bucket_policy" {
#   statement {
#     principals {
#       identifiers = ["logging.s3.amazonaws.com"]
#       type        = "Service"
#     }
#     actions   = ["s3:PutObject"]
#     resources = ["${aws_s3_bucket.logging.arn}/*"]
#     condition {
#       test     = "StringEquals"
#       variable = "aws:SourceAccount"
#       values   = [data.aws_caller_identity.current.account_id]
#     }
#   }
# }

# resource "aws_s3_bucket_policy" "logging" {
#   bucket = aws_s3_bucket.logging.bucket
#   policy = data.aws_iam_policy_document.logging_bucket_policy.json
# }


# S3 BUCKET FOR LOGGING (Lambda)


# ROUTE 53
resource "aws_route53_zone" "primary" {
  name = "florianjanssens.de"
}


import {
  to = aws_route53_zone.myzone
  identity = {
    zone_id = "Z1D633PJN98FT9"
  }
}

# API-GATEWAY


# LAMBDA 


# AWS SES


# IAM ROLE MODUL


# IAM ROLE LAMBDA-SES


# Budget 
# Monitoring (Cloudwatch)
