terraform {
  required_version = "1.13.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.13.0"
    }
  }

  backend "s3" {
    bucket       = "cos-nu-ai-tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
