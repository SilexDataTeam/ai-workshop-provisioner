variable "ai_workshop_eks_cluster_name" {
  type = string
}

variable "ai_workshop_eks_subnets" {
  type = list(string)
}

variable "aws_administrator_role_arn" {
  description = "The ARN of the AWS IAM role that has administrator access to the AWS account for EKS ClusterAdmin access."
  type        = string
}

variable "number_of_users" {
  type    = number
  default = 30
}
