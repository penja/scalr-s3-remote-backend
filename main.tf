variable "region" {
    description = "The AWS region to deploy resources into"
    default     = "us-east-1"
}

variable "bucket_name" {
    description = "The name of the S3 bucket to create"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false      
  lower   = true           
}

locals {
  bucket_name = "${var.bucket_name}-${random_string.bucket_suffix.result}"
}

provider "aws" {
    region = var.region
}

# Create the S3 bucket to store the Terraform state file
resource "aws_s3_bucket" "terraform_state" {
  count = 5000
  bucket = "${local.bucket_name}-${count.index}"
  acl    = "private"

  versioning {
    enabled = true
  }
  force_destroy=true
}

# Create a DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  count = 5000
  name         = "${local.bucket_name}-${count.index}-locks"
  billing_mode = "PAY_PER_REQUEST" # This uses on-demand pricing for DynamoDB

  attribute {
    name = "LockID"
    type = "S"
  }

  hash_key = "LockID"

  # Enable point-in-time recovery (optional)
  point_in_time_recovery {
    enabled = true
  }

  # Add a TTL to reduce storage costs for expired locks (optional)
  ttl {
    attribute_name = "TTL"
    enabled        = true
  }

  tags = {
    Name        = "TerraformLockTable"
    Environment = "dev"
  }
}

terraform {
  backend "s3" {
    bucket         = "alfiia-terraform-state-bucket"
    key            = "global/s3/terraform.tfstate"  # Path in S3 where the state file will be stored
    region         = "us-west-2"
    encrypt        = true                           # Enables server-side encryption
    dynamodb_table = "terraform-locks"      # Name of the DynamoDB table for state locking
  }
}

