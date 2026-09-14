variable "aws_region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto. Se usa como nombre del repositorio ECR."
  type        = string
  default     = "devops-bootcamp-demo"
}

variable "max_images_to_keep" {
  description = "Cantidad máxima de imágenes taggeadas a retener antes de que la lifecycle policy empiece a borrar las más viejas."
  type        = number
  default     = 15
}
