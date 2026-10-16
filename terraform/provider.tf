# Same dual-target pattern as Sessions 18 and 19: one provider block, every
# LocalStack-only setting gated on var.use_localstack. With
# `-var use_localstack=false` this collapses to `provider "aws" { region = ... }`
# and the SDK's normal credential chain (env vars / ~/.aws/credentials /
# instance role) is used.
#
# Honest note: LocalStack community implements ec2 / iam / sts, but NOT eks
# (EKS is a Pro feature). The endpoints are still listed so that every
# API call made with use_localstack = true goes to port 4566 and fails loudly
# there instead of silently reaching real AWS with fake credentials.
provider "aws" {
  region = var.aws_region

  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null

  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  s3_use_path_style           = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      ec2 = var.localstack_endpoint
      iam = var.localstack_endpoint
      sts = var.localstack_endpoint
      eks = var.localstack_endpoint
    }
  }

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
          },
    var.tags,
  )
}
