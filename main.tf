provider "aws" {
  region = "us-east-1"
}
# An example resource that does nothing.
resource "null_resource" "example" {
  triggers = {
    value = "A example resource that does nothing!"
  }
}

# S3 BUCKET WEBSITE CONTENTS
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "cactify-website-content"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }

  tags = {
    Name = var.s3_bucket_name
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  bucket = aws_s3_bucket.cactify-website-content.id
  policy = data.aws_iam_policy_document.allow_access_from_another_account.json
}

data "aws_iam_policy_document" "PolicyForCloudFrontPrivateContent" {
  statement {
    sid       = "AllowCloudFrontServicePrincipal"
    actions   = ["s3:GetObject"]
    resources = [aws_s3_bucket.cactify-website-content.arn]
    effect    = "Allow"
    principals {
      identifiers = ["cloudfront.amazonaws.com"]
      type        = ""

    }
    condition {
      test     = StringEquals
      values   = ["arn:aws:cloudfront::666607745287:distribution/????????"]
      variable = "AWS:SourceArn"
    }
  }
}




# S3 BUCKET FOR LOGGING


# ROUTE 53


# CLOUDFRONT


# API-GATEWAY


# LAMBDA 


# AWS SES


# IAM ROLE MODUL


# IAM ROLE LAMBDA-SES


# Budget 
# Monitoring (Cloudwatch)
