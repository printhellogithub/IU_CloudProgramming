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


# S3 BUCKET FOR LOGGING


# CLOUDFRONT


# API-GATEWAY


# LAMBDA 


# AWS SES


# IAM ROLE MODUL


# Budget 
# Monitoring (Cloudwatch)
