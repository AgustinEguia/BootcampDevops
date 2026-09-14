# main.tf (00-backend)
# ----------------------
# Crea el bucket S3 (guarda el .tfstate) y la tabla DynamoDB (locking)
# que los módulos 10-network, 20-ecr y 30-eks van a usar como backend
# remoto compartido. Tener el state en S3 (en vez de en el disco de cada
# desarrollador) es lo que permite que un equipo trabaje sobre la misma
# infraestructura sin pisarse el uno al otro.
provider "aws" {
  region = var.aws_region
}

# Bucket S3 para el remote state. Nombre único a nivel GLOBAL en AWS (no
# sólo en tu cuenta), por eso agregamos el account id como sufijo.
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  # Protección extra: evita que un `terraform destroy` accidental de ESTE
  # módulo borre el bucket que contiene el state de TODOS los demás
  # módulos (lo cual sería catastrófico: perderías el registro de qué
  # infraestructura existe).
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Versionado: cada cambio de state queda guardado como una versión
# distinta del objeto en S3. Si un `apply` corrompe el state (pasa más de
# lo que gustaría), se puede restaurar la versión anterior del archivo.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# El state de Terraform puede contener valores sensibles en texto plano
# (passwords, tokens que se generaron como recursos). Encriptar el bucket
# es una capa extra de defensa, aunque el acceso ya debería estar
# restringido por IAM.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Tabla DynamoDB usada para el "state locking": cuando alguien corre
# `terraform apply`, Terraform escribe un lock en esta tabla, y si otra
# persona intenta correr `apply` al mismo tiempo, falla con un error claro
# en vez de corromper el .tfstate por una escritura concurrente.
resource "aws_dynamodb_table" "tflock" {
  name         = "${var.project_name}-tflock"
  billing_mode = "PAY_PER_REQUEST" # sin capacidad provisionada: pagás sólo por uso, ideal para uso esporádico de un curso.
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
