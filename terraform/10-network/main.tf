# main.tf (10-network)
# -----------------------
# Usamos el módulo público y ampliamente usado terraform-aws-modules/vpc
# en vez de escribir los recursos aws_vpc/aws_subnet/aws_route_table a
# mano: es el estándar de facto de la comunidad, está muy testeado, y
# ahorra cientos de líneas de HCL repetitivo. Es importante que los
# alumnos sepan LEER un módulo de terceros (sus variables de entrada y
# outputs) tanto como saber escribir recursos propios.
provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  # NAT Gateway: permite que instancias en subnets PRIVADAS (los nodos de
  # EKS) salgan a Internet (por ejemplo, para pullear imágenes de ECR o
  # descargar paquetes) SIN tener una IP pública propia expuesta.
  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags especiales que EKS y su Load Balancer Controller usan para
  # DESCUBRIR automáticamente en qué subnets puede crear recursos
  # (Load Balancers públicos en las públicas, internos en las privadas).
  # Sin estos tags, el ALB Controller no sabría dónde crear los ALBs.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                     = "1"
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"            = "1"
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}
