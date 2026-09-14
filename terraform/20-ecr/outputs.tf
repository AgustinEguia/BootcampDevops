output "ecr_repository_url" {
  description = "URL del repositorio ECR. Se usa como IMAGE_NAME en el pipeline de CI/CD cuando se despliega contra AWS."
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN del repositorio, útil para políticas de IAM que necesiten dar permiso de push/pull."
  value       = aws_ecr_repository.app.arn
}
