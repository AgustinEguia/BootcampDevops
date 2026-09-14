output "cluster_name" {
  description = "Nombre del cluster EKS."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint de la API de Kubernetes."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "CA data del cluster, usado para armar el kubeconfig."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "configure_kubectl" {
  description = "Comando para configurar kubectl apuntando a este cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
