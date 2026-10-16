terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Only used to read the TLS certificate thumbprint of the cluster's OIDC
    # issuer (eks.tf) so the IAM OIDC provider can be created.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
