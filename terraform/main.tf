terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"  # 東京リージョン
}


resource "aws_s3_bucket" "first_bucket" {

  bucket = "oruby-helper-test-bucket-prod"

  tags = {
    Name        = "Oruby Helper Test Bucket"
    Environment = "development"
    Purpose     = "Learning Terraform"
  }

  lifecycle {
    prevent_destroy = false
    create_before_destroy = false
  }
}

resource "aws_s3_bucket_public_access_block" "first_bucket_pab" {
  bucket = aws_s3_bucket.first_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket_name" {
  description = "作成されたS3バケットの名前"
  value       = aws_s3_bucket.first_bucket.id
}
