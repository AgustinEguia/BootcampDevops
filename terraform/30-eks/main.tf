# main.tf (30-eks)
# --------------------
# Cluster EKS con el módulo público terraform-aws-modules/eks, sobre la
# VPC creada por el módulo 10-network. Usa un managed node group (AWS se
# encarga del ciclo de vida de las instancias EC2 worker) y habilita IRSA
# (IAM Roles for Service Accounts).
provider "aws" {
  region = var.aws_region
}

# Leemos los outputs del módulo 10-network (vpc_id, subnets) desde SU
# remote state en S3, en vez de hardcodear IDs a mano. Este es el patrón
# estándar de Terraform para que módulos separados (con su propio ciclo
# de vida y su propio `terraform apply`) se puedan "pasar" información
# entre sí sin acoplar sus states en uno solo.
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.tfstate_bucket
    key    = "10-network/terraform.tfstate"
    region = var.aws_region
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.project_name
  cluster_version = var.cluster_version

  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  # Deja el endpoint de la API de Kubernetes accesible públicamente (para
  # que kubectl funcione desde la laptop de cada alumno sin VPN). En un
  # cluster de producción real, lo típico es restringir esto a la red
  # corporativa (cluster_endpoint_public_access_cidrs) o desactivar el
  # acceso público directamente.
  cluster_endpoint_public_access = true

  # IRSA (IAM Roles for Service Accounts): crea el proveedor OIDC que
  # permite que un ServiceAccount de Kubernetes "asuma" un rol de IAM sin
  # necesitar credenciales de AWS de larga duración dentro del pod. Es la
  # forma moderna y segura de que, por ejemplo, un pod lea/escriba en S3:
  # sin esto, la alternativa (mucho peor) sería inyectar un AWS access
  # key/secret como Secret de Kubernetes.
  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      # AL2023 es la AMI managed más moderna que ofrece EKS (basada en
      # Amazon Linux 2023), con mejor soporte de seguridad de largo plazo
      # que la AMI "AL2" clásica.
      ami_type = "AL2023_x86_64_STANDARD"

      labels = {
        role = "worker"
      }
    }
  }

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}
