output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_group_asg_name" {
  description = "Auto Scaling Group que respalda el node group (lo usa el schedule FinOps)."
  value       = aws_eks_node_group.default.resources[0].autoscaling_groups[0].name
}
