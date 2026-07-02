variable "s3_bucket_name" {
  description = "S3 Bucket containing website contents, origin of cloudfront distribution"
  type        = string
  default     = "cactify-website-content"
}

