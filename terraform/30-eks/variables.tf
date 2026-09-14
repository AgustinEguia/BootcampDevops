variable "aws_region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto. Se usa como nombre del cluster EKS."
  type        = string
  default     = "devops-bootcamp-demo"
}

variable "cluster_version" {
  description = "Versión de Kubernetes del control plane de EKS."
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "Tipos de instancia EC2 para el managed node group. t3.medium alcanza para el demo del curso."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Mínimo de nodos del node group."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Máximo de nodos del node group."
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Cantidad deseada de nodos al crear el cluster."
  type        = number
  default     = 2
}

variable "tfstate_bucket" {
  description = "Nombre del bucket S3 donde vive el remote state de 10-network (para leer sus outputs vía terraform_remote_state). Es el mismo bucket que crea 00-backend."
  type        = string
}
