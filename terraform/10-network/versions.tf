terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Backend remoto: usa el bucket S3 + tabla DynamoDB creados por el
  # módulo 00-backend. NOTA: Terraform no permite interpolar variables
  # acá adentro (es una limitación conocida del bloque `backend`), así
  # que estos valores hay que completarlos a mano después de aplicar
  # 00-backend (o pasarlos con `terraform init -backend-config=...`).
  backend "s3" {
    bucket         = "<REEMPLAZAR_CON_OUTPUT_tfstate_bucket_name_DE_00-backend>"
    key            = "10-network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "<REEMPLAZAR_CON_OUTPUT_tflock_table_name_DE_00-backend>"
    encrypt        = true
  }
}
