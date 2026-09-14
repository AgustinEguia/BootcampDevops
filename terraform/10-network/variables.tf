variable "aws_region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo/tag de los recursos."
  type        = string
  default     = "devops-bootcamp-demo"
}

variable "vpc_cidr" {
  description = "Rango CIDR de la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones a usar. Se recomiendan al menos 2 para alta disponibilidad."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# EKS necesita saber en qué subnets puede meter nodos/pods. Le pasamos
# rangos /24 (256 IPs) por cada AZ, tanto públicos como privados: alcanza
# de sobra para el tamaño de cluster de un curso.
variable "public_subnet_cidrs" {
  description = "CIDRs de las subnets públicas (una por AZ)."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs de las subnets privadas (una por AZ), donde van a vivir los nodos de EKS."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "single_nat_gateway" {
  description = "Si es true, crea UN SOLO NAT Gateway compartido por todas las AZs (más barato, menos disponible). Si es false, crea uno por AZ (recomendado en prod real, más caro). Para el curso, dejamos true por default para minimizar costos."
  type        = bool
  default     = true
}
