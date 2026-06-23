terraform {
  backend "s3" {
    bucket = "tf-state-backend-for-cloudprogramming-494952235840-us-east-1-an"
    key    = "terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    use_lockfile = true
  }
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}