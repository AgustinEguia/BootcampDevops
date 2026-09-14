output "vpc_id" {
  description = "ID de la VPC creada. Lo consume el módulo 30-eks."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas (donde van los nodos de EKS)."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas (donde van los Load Balancers públicos)."
  value       = module.vpc.public_subnets
}
