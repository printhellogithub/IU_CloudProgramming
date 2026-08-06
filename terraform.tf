terraform {
  backend "s3" {
    bucket       = "tfstate-bucket-for-cloudprogramming-666607745287-us-east-1-an"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7.1"
    }
  }

  required_version = ">= 1.5"
}