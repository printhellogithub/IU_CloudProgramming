variable "s3_website_content_bucket_name" {
  description = "S3 Bucket containing website contents, origin of cloudfront distribution"
  type        = string
  default     = "cactify-website-content"
}

variable "s3_lambda_bucket_name" {
  description = "S3 Bucket containing lambda function"
  type        = string
  default     = "cactify-lambda-bucket"
}

variable "domain_config" {
  type = object({
    main_domain = string
    subdomain   = string
  })
  default = {
    main_domain = "florianjanssens.de"
    subdomain   = "cactify"
  }
}