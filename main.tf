# PROVIDER
provider "aws" {
  region = "us-east-1"
}

# LOCALS
locals {
  s3_origin_id          = aws_s3_bucket.cactify-website-content.id
  cactify_domain        = "${var.domain_config.subdomain}.${var.domain_config.main_domain}"
  hosted_zone_id        = data.aws_route53_zone.cactify_domain.zone_id
  api_gateway_origin_id = aws_apigatewayv2_api.contact.id
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
  bucket = format("cactify-website-content-%s-%s", data.aws_caller_identity.current.account_id, data.aws_region.current.name)
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
# Error 403
resource "aws_s3_object" "custom_403" {
  bucket       = aws_s3_bucket.cactify-website-content.bucket
  key          = "403.html"
  source       = "./src/403.html"
  etag         = filemd5("./src/403.html")
  content_type = "text/html"
}
# Error 404
resource "aws_s3_object" "custom_404" {
  bucket       = aws_s3_bucket.cactify-website-content.bucket
  key          = "404.html"
  source       = "./src/404.html"
  etag         = filemd5("./src/404.html")
  content_type = "text/html"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

# ACM (Certificate Manager) + DNS-Validierung
# ----------------------------------------------------------------
resource "aws_acm_certificate" "cactify_cf" {
  provider                  = aws
  domain_name               = local.cactify_domain
  subject_alternative_names = ["www.${local.cactify_domain}", "api.${local.cactify_domain}"]
  validation_method         = "DNS"
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
  # S3-Website-Contents-Origin
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
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # price_class_100 ist nicht weltweit: Nur United States, Mexico, and Canada, Europe, Israel, and Türkiye
  # Für eine weltweite Abdeckung wäre "PriceClass_All" erforderlich. 
  # Diese Einstellung wurde zum Schutz des Studenten im Rahmen des Projektes auf "PriceClass_100" gestellt.
  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = aws_acm_certificate_validation.cactify_cf.certificate_arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  custom_error_response {
    error_code         = "403"
    response_page_path = "/403.html"
  }
  custom_error_response {
    error_code         = "404"
    response_page_path = "/404.html"
  }

  tags = {
    Environment = "production"

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

# LOGGING
# ----------------------------------------------------------------
# 1. CloudFront Logging

# Cloudwatch Log Delivery Source
resource "aws_cloudwatch_log_delivery_source" "cactify_distribution" {
  name         = "cactify_distribution"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.cactify_distribution.arn
}

# S3 Log Bucket
resource "aws_s3_bucket" "cactify-logging" {
  bucket        = format("cactify-logging-bucket-%s-%s", data.aws_caller_identity.current.account_id, data.aws_region.current.name)
  force_destroy = true
}

# Log Delivery Destination
resource "aws_cloudwatch_log_delivery_destination" "cactify_distribution" {
  name          = "s3-destination"
  output_format = "parquet"

  delivery_destination_configuration {
    destination_resource_arn = "${aws_s3_bucket.cactify-logging.arn}/prefix"
  }
}

# Log Delivery
resource "aws_cloudwatch_log_delivery" "cactify_distribution" {

  delivery_source_name     = aws_cloudwatch_log_delivery_source.cactify_distribution.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cactify_distribution.arn

  s3_delivery_configuration {
    suffix_path = format("/%s/%s/{yyyy}/{MM}/{dd}/{HH}", data.aws_caller_identity.current.account_id, aws_cloudfront_distribution.cactify_distribution.id)
  }
}
# ----------------------------------------------------------------
# API-GATEWAY
# ----------------------------------------------------------------

# API-Gateway: Domain Name
resource "aws_apigatewayv2_domain_name" "contact" {
  domain_name = "api.${var.domain_config.subdomain}.${var.domain_config.main_domain}"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.cactify_cf.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

# Route53 Record for API-Gateway -> api.cactify.DOMAIN/contact
resource "aws_route53_record" "api_gateway" {
  name    = aws_apigatewayv2_domain_name.contact.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.cactify_domain.zone_id

  alias {
    name                   = aws_apigatewayv2_domain_name.contact.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.contact.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# API-Gateway: API
resource "aws_apigatewayv2_api" "contact" {
  name          = "contact-api"
  protocol_type = "HTTP"
  description   = "Forwards incomming request to Lambda function"

  cors_configuration {
    allow_headers = ["content-type"]
    allow_methods = ["POST", "OPTIONS"]
    allow_origins = [
      "https://${local.cactify_domain}",
      "https://www.${local.cactify_domain}"
    ]
    expose_headers = ["*"]
    max_age        = 3600
  }
}

# API-Gateway: Mapping
resource "aws_apigatewayv2_api_mapping" "contact" {
  api_id      = aws_apigatewayv2_api.contact.id
  domain_name = aws_apigatewayv2_domain_name.contact.id
  stage       = aws_apigatewayv2_stage.contact.id
}

# API-Gateway: Stage
resource "aws_apigatewayv2_stage" "contact" {
  api_id = aws_apigatewayv2_api.contact.id

  name        = "serverless_lambda_stage"
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
  # Um Kosten durch Missbrauch auszuschließen oder zu reduzieren
  route_settings {
    route_key              = aws_apigatewayv2_route.contact.route_key
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }
}

# API-Gateway: Integration
resource "aws_apigatewayv2_integration" "contact" {
  api_id           = aws_apigatewayv2_api.contact.id
  integration_type = "AWS_PROXY"

  integration_method = "POST"
  integration_uri    = aws_lambda_function.contact.invoke_arn
}

# API-Gateway: Route
resource "aws_apigatewayv2_route" "contact" {
  api_id = aws_apigatewayv2_api.contact.id

  route_key = "POST /contact"
  target    = "integrations/${aws_apigatewayv2_integration.contact.id}"
}

# API-Gateway: Cloudwatch Log
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.contact.name}"

  retention_in_days = 7
}

# API-Gateway: Lambda Permission
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.contact.execution_arn}/*/*"
}

# API-Gateway: Deployment
# resource "aws_apigatewayv2_deployment" "contact" {
#   api_id      = aws_apigatewayv2_api.contact.id
#   description = "Contact deployment"

#   lifecycle {
#     create_before_destroy = true
#   }
# }
# ----------------------------------------------------------------
# LAMBDA 
# ----------------------------------------------------------------
# S3 Bucket for Lambda Function
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = format("cactify-lambda-bucket-%s-%s", data.aws_caller_identity.current.account_id, data.aws_region.current.name)

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
  acl    = "private"
}

# Package the Lambda function code
data "archive_file" "lambda-contact-function" {
  type        = "zip"
  source_dir  = "./lamb-funct-package"
  output_path = "./lambda/function.zip"
}

# Upload archive to S3
resource "aws_s3_object" "lambda-contact-function" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "function.zip"
  source = data.archive_file.lambda-contact-function.output_path

  etag = filemd5(data.archive_file.lambda-contact-function.output_path)
}

# Lambda function
resource "aws_lambda_function" "contact" {

  function_name = "contact_lambda_function"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda-contact-function.key

  runtime = "python3.13"
  handler = "contact.lambda_handler"

  source_code_hash = data.archive_file.lambda-contact-function.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  timeout = 15

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

# LAMBDA IAM Exec ROLE
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

# Policy provides write permissions to CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ses_policy" {
  name = "lambda-send-with-ses"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ]
      Resource = "*"
      Condition = {
        StringEquals = {
          "ses:FromAddress" = "contact@cactify.florianjanssens.de"
        }
      }
    }]
  })
}

# ----------------------------------------------------------------
# AWS SES
# ----------------------------------------------------------------

# Für den/die Tester*in dieser Software: Die Email-Adresse service@florianjanssens.de wurde hier verwendet. Wenn Sie Ihre eigene Domain nutzen,
# wird Amazon SES versuchen, service@DOMAIN zu verifizieren. Bitte nutzen Sie hier eine Adresse, auf die Sie zugriff haben. 
# Diese Mail-Adresse ist die des Service-Teams der fiktiven Cactify-App. 
resource "aws_sesv2_email_identity" "service" {
  email_identity = "service@${var.domain_config.main_domain}"
}

resource "aws_ses_domain_identity" "cactify_domain" {
  domain = local.cactify_domain
}

resource "aws_sesv2_email_identity" "test" {
  email_identity = var.test_email_for_ses
}

resource "aws_route53_record" "cactify_amazonses_verification_record" {
  zone_id = data.aws_route53_zone.cactify_domain.zone_id
  name    = "_amazonses.${var.domain_config.subdomain}.${var.domain_config.main_domain}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.cactify_domain.verification_token]
}

resource "aws_sesv2_configuration_set" "main" {
  configuration_set_name = "my-cactify-config-set"
}

resource "aws_sesv2_configuration_set_event_destination" "main" {
  configuration_set_name = aws_sesv2_configuration_set.main.configuration_set_name
  event_destination_name = "SES-main"

  event_destination {
    cloud_watch_destination {
      dimension_configuration {
        dimension_name          = "EventType"
        default_dimension_value = "Unknown"
        dimension_value_source  = "MESSAGE_TAG"
      }
      dimension_configuration {
        dimension_name          = "RecipientDomain"
        default_dimension_value = "Internal"
        dimension_value_source  = "EMAIL_HEADER"
      }
    }

    enabled              = true
    matching_event_types = ["SEND", "BOUNCE", "COMPLAINT", "DELIVERY", "REJECT"]
  }
}
