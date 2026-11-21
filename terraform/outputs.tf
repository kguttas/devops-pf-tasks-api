output "cluster_name" {
  description = "Nombre del cluster EKS."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint de la API de Kubernetes."
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "ID de la VPC."
  value       = module.network.vpc_id
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR."
  value       = aws_ecr_repository.app.repository_url
}

output "kubeconfig_command" {
  description = "Comando para configurar kubectl contra el cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
