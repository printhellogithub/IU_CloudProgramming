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
  bucket = format("cactify-website-content-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.current.name)
  #  bucket_namespace = "account-regional"

  tags = {
    Name = var.s3_website_content_bucket_name
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
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Adding Website-Contents to S3-cactify-website-content-Bucket
#Index.html
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.cactify-website-content.bucket
  key          = "index.html"
  source       = "./src/index.html"
  etag         = filemd5("./src/index.html")
  content_type = "text/html"
}
# Download_Button_V1_green.svg
resource "aws_s3_object" "Download_Button" {
  bucket       = aws_s3_bucket.cactify-website-content.bucket
  key          = "Download_Button_V1_green.svg"
  source       = "./src/Download_Button_V1_green.svg"
  etag         = filemd5("./src/Download_Button_V1_green.svg")
  content_type = "image/svg+xml"
}
# Kaktus_V1.svg
resource "aws_s3_object" "Kaktus" {
  bucket       = aws_s3_bucket.cactify-website-content.bucket
  key          = "Kaktus_V1.svg"
  source       = "./src/Kaktus_V1.svg"
  etag         = filemd5("./src/Kaktus_V1.svg")
  content_type = "image/svg+xml"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

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
# ----------------------------------------------------------------
# API-GATEWAY
# ----------------------------------------------------------------
# API-Gateway: API
resource "aws_apigatewayv2_api" "contact" {
  name          = "contact-api"
  protocol_type = "HTTP"
  description   = "Forwards incomming Request to Lambda function"
}

resource "aws_apigatewayv2_stage" "contact" {
  api_id = aws_apigatewayv2_api.contact.id

  name = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}

# API-Gateway: Integration
resource "aws_apigatewayv2_integration" "contact" {
  api_id           = aws_apigatewayv2_api.contact.id
  integration_type = "AWS_PROXY"

  integration_method = "POST"
  # integration_uri    = "https://example.com/{proxy}"
}

# API-Gateway: Route
resource "aws_apigatewayv2_route" "contact" {
  api_id    = aws_apigatewayv2_api.contact.id

  route_key = "POST /contact"
  target = "integrations/${aws_apigatewayv2_integration.contact.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.contact.name}"

  retention_in_days = 7
}

resource "aws_lambda_permission" "api_gw" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact.function_name
  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# API-Gateway: Deployment
resource "aws_apigatewayv2_deployment" "contact" {
  api_id      = aws_apigatewayv2_api.contact.id
  description = "Contact deployment"

  lifecycle {
    create_before_destroy = true
  }
}
# ----------------------------------------------------------------
# LAMBDA 
# ----------------------------------------------------------------
# S3 Bucket for Lambda Function
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = format("cactify-lambda-bucket-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.current.name)

  tags = {
    Name = var.s3_lambda_bucket_name
  }
}

resource "aws_s3_bucket_ownership_controls" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "lambda_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.lambda_bucket]

  bucket = aws_s3_bucket.lambda_bucket.id
  acl = "private"
}

# Package the Lambda function code
data "archive_file" "lambda-contact-function" {
  type        = "zip"
  source_file = "./lambda/contact.py"
  output_path = "./lambda/function.zip"
}
# Upload archive to S3
resource "aws_s3_object" "lambda-contact-function" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key = "function.zip"
  source = data.archive_file.lambda-contact-function.output_path

  etag = filemd5(data.archive_file.lambda-contact-function.output_path)
}

# Lambda function
resource "aws_lambda_function" "contact" {
  
  function_name = "contact_lambda_function"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key = aws_s3_object.lambda-contact-function.key

  runtime = "python3.13"
  handler       = "contact.lambda_handler"

  source_code_hash = data.archive_file.lambda-contact-function.output_base64sha256

  role          = aws_iam_role.contact.arn

  environment {
    variables = {
      ENVIRONMENT = "production"
      LOG_LEVEL   = "info"
    }
  }

  tags = {
    Environment = "production"
    Application = "contact"
  }
}

resource "aws_cloudwatch_log_group" "contact" {
  name = "/aws/lambda/${aws_lambda_function.contact.function_name}"

  # Retention für Produktion eher 30 Tage. Um auf jeden Fall im Free Tier zu bleiben - hier 7 Tage.
  retention_in_days = 7
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  
}

# # IAM role for Lambda execution
# data "aws_iam_policy_document" "assume_role" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["lambda.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

# resource "aws_iam_role" "contact" {
#   name               = "lambda_execution_role"
#   assume_role_policy = data.aws_iam_policy_document.assume_role.json
# }

# ----------------------------------------------------------------
# AWS SES
# ----------------------------------------------------------------
resource "aws_sesv2_email_identity" "service" {
  email_identity = "service@florianjanssens.de"
}

# resource "aws_sesv2_email_identity" "cactify-domain" {
#   email_identity = "cactify.florianjanssens.de"
#   configuration_set_name = aws_sesv2_configuration_set.main.configuration_set_name

#   dkim_signing_attributes {
#     domain_signing_private_key = "MIIJKAIBAAKCAgEA2Se7p8zvnI4yh+Gh9j2rG5e2aRXjg03Y8saiupLnadPH9xvM..." #PEM private key without headers or newline characters
#     domain_signing_selector    = "example"
#   }
# }

resource "aws_ses_domain_identity" "cactify_domain" {
  domain = "cactify.florianjanssens.de"
}

resource "aws_route53_record" "cactify_amazonses_verification_record" {
  zone_id = "Z06874663LA9REHRJ0CLV"
  name    = "_amazonses.cactify.florianjanssens.de"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.cactify_domain.verification_token]
}

resource "aws_sesv2_configuration_set" "main" {
  configuration_set_name = "my-cactify-config-set"
}

# IAM ROLE LAMBDA-SES
resource "aws_iam_role" "lambda-ses-role" {
  name = lambda-ses-role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_ses_policy" {
  name = lambda-send-with-ses
  role = aws_iam_role.lambda-ses-role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendEmail", "ses:SendRawEmail"]
      Resource = [
        aws_sesv2_email_identity.cactify-domain.arn,
        aws_sesv2_configuration_set.main.arn
      ]
    }]
  })
}

resource "aws_sesv2_configuration_set_event_destination" "main" {
  configuration_set_name = aws_sesv2_configuration_set.main.configuration_set_name
  event_destination_name = "SES-main"

  event_destination {
    cloud_watch_destination {
      dimension_configuration {
        dimension_name = "EventType"
        default_dimension_value = "Unknown"
        dimension_value_source = "MESSAGE_TAG"
      }
      dimension_configuration {
        dimension_name = "RecipientDomain"
        default_dimension_value = "Internal"
        dimension_value_source = "EMAIL_HEADER"
      }
    }

    enabled              = true
    matching_event_types = ["send", "bounce", "complaint", "delivery", "reject"]
  }
}

# Monitoring (Cloudwatch)
