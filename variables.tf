variable "s3_bucket_name" {
  description = "S3 Bucket containing website contents, origin of cloudfront distribution"
  type        = string
  default     = "cactify-website-content"
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