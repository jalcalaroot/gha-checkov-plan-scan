terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

resource "aws_s3_bucket" "test" {
  #checkov:skip=CKV_AWS_144:no cross-region replication needed for this test fixture
  #checkov:skip=CKV_AWS_18:no access logging needed for this test fixture
  #checkov:skip=CKV_AWS_21:no versioning needed for this test fixture
  #checkov:skip=CKV2_AWS_61:no lifecycle configuration needed for this test fixture
  #checkov:skip=CKV2_AWS_62:no event notifications needed for this test fixture
  #checkov:skip=CKV_AWS_145:default encryption is enough for this test fixture
  #checkov:skip=CKV2_AWS_6:no public access block needed for this isolated test fixture
  #checkov:skip=CKV_AWS_57:not applicable to this test fixture, single-purpose bucket
  #checkov:skip=CKV_AWS_20:not applicable to this test fixture, no public read intended anyway
  bucket = "example-test-bucket-autopilot"
}

resource "aws_iam_role" "test" {
  name = "example-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
