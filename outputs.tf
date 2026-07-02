output "cactify-website-content-ARN" {
  description = "ARN of s3 cactify-website-content "
  value       = aws_s3_bucket.cactify-website-content.s3_bucket_arn
}

output "cactify-website-content-bucket-policy" {
  description = "Bucket-Policy of s3 cactify-website-content "
  value       = aws_s3_bucket.cactify-website-content.s3_bucket_policy
}
