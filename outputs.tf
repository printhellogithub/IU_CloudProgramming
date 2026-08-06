output "cactify-website-content-ARN" {
  description = "ARN of s3 cactify-website-content "
  value       = aws_s3_bucket.cactify-website-content.arn
}

output "lambda_bucket_name" {
  description = "Name of the S3 bucket used to store the lambda function code."

  value = aws_s3_bucket.lambda_bucket.id
}

output "function_name" {
  description = "Name of the Lambda function."

  value = aws_lambda_function.contact.function_name
}

output "base_url" {
  description = "Base URL for API Gateway stage."

  value = aws_apigatewayv2_stage.contact.invoke_url
}

################################################################################
# Distribution
################################################################################
# Quelle: https://github.com/terraform-aws-modules/terraform-aws-cloudfront/blob/master/outputs.tf


output "cloudfront_distribution_id" {
  description = "The identifier for the distribution."
  value       = try(aws_cloudfront_distribution.cactify_distribution.id, null)
}

output "cloudfront_distribution_arn" {
  description = "The ARN (Amazon Resource Name) for the distribution."
  value       = try(aws_cloudfront_distribution.cactify_distribution.arn, null)
}

output "cloudfront_distribution_status" {
  description = "The current status of the distribution. Deployed if the distribution's information is fully propagated throughout the Amazon CloudFront system."
  value       = try(aws_cloudfront_distribution.cactify_distribution.status, null)
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name corresponding to the distribution."
  value       = try(aws_cloudfront_distribution.cactify_distribution.domain_name, null)
}

output "cloudfront_distribution_last_modified_time" {
  description = "The date and time the distribution was last modified."
  value       = try(aws_cloudfront_distribution.cactify_distribution.last_modified_time, null)
}


