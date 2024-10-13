output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.ai_workshop_eks_cluster.name
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster"
  value       = aws_eks_cluster.ai_workshop_eks_cluster.endpoint
}

output "cluster_ca_certificate" {
  description = "The CA certificate for the EKS cluster"
  value       = base64decode(aws_eks_cluster.ai_workshop_eks_cluster.certificate_authority.0.data)
}

output "load_balancer_controller_iam_role_arn" {
  description = "The ARN of the IAM role used by the AWS Load Balancer Controller"
  value       = module.load_balancer_controller_irsa_role.iam_role_arn
}

output "cluster_autoscaler_iam_role_arn" {
  description = "The ARN of the IAM role used by the Cluster Autoscaler"
  value       = module.cluster_autoscaler_irsa_role.iam_role_arn
}
