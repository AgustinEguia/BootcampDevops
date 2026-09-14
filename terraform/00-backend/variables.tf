variable "aws_region" {
  description = "Región de AWS donde se crea la infraestructura del backend."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo de los nombres de recursos."
  type        = string
  default     = "devops-bootcamp-demo"
}

variable "environment" {
  description = "Ambiente lógico (curso, sandbox, etc). No confundir con dev/prod de K8s: esto es a nivel de cuenta de AWS."
  type        = string
  default     = "curso"
}
