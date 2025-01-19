variable "number_of_users" {
  type    = number
  default = 30
}

variable "user_prefix" {
  type    = string
  default = "user"
}

variable "ai_workshop_eks_cluster_name" {
  type = string
}

variable "cluster_ca_certificate" {
  type = string
}

variable "cluster_autoscaler_iam_role_arn" {
  type = string
}

variable "load_balancer_controller_iam_role_arn" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "ai_workshop_domain_name" {
  type = string
}

variable "ai_workshop_route53_zone_name" {
  type = string
}

variable "ai_workshop_docker_registry_username" {
  description = "The docker registry username for the EKS cluster."
  type        = string
}

variable "ai_workshop_docker_registry_password" {
  description = "The docker registry password for the EKS cluster."
  type        = string
  sensitive   = true
}

variable "ssh_private_key" {
  description = "The SSH private key for GitHub deploy key."
  type        = string
  sensitive   = true
}

variable "ai_workshop_shared_password" {
  type = string
}

variable "ai_workshop_materials_git_repo_url" {
  description = "The git repo url for the repo that contains the workshop materials."
  type        = string
}

variable "openai_api_key" {
  description = "The OpenAI API key."
  type        = string
}

variable "tavily_api_key" {
  description = "The Tavily API key."
  type        = string
}

variable "hf_token" {
  description = "HuggingFace API key."
  type        = string
}