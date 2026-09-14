# versions.tf
# -------------
# Fijar versiones (de Terraform y de providers) es clave para
# reproducibilidad: sin esto, un `terraform init` corrido en dos
# máquinas distintas (o en dos momentos distintos) puede bajar versiones
# distintas del provider de AWS y comportarse diferente.
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Este módulo (00-backend) es el ÚNICO que NO usa un backend remoto:
  # es el que CREA el backend remoto que los demás módulos van a usar.
  # Por eso acá el state queda local (terraform.tfstate en este mismo
  # directorio) — hay que resguardarlo bien la primera vez (por ejemplo,
  # commiteando el bucket/tabla creados como "pets" que casi nunca se
  # recrean, y opcionalmente migrando este mismo módulo a S3 una vez que
  # el bucket existe, con `terraform init -migrate-state`).
}
