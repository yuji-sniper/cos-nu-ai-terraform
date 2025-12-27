provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  region = "ap-northeast-1"
  alias  = "apne1"
}
