terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
  }

  backend "s3" {
    bucket         = "<REEMPLAZAR_CON_OUTPUT_tfstate_bucket_name_DE_00-backend>"
    key            = "30-eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "<REEMPLAZAR_CON_OUTPUT_tflock_table_name_DE_00-backend>"
    encrypt        = true
  }
}
