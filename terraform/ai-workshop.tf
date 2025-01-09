module "ai_workshop_eks_cluster" {
  source                       = "./eks"
  ai_workshop_eks_cluster_name = var.ai_workshop_eks_cluster_name
  ai_workshop_eks_subnets      = var.ai_workshop_eks_subnets
  aws_administrator_role_arn   = var.aws_administrator_role_arn
  number_of_users              = var.number_of_users
}

module "ai_workshop_config" {
  source                                = "./eks-config"
  ai_workshop_eks_cluster_name          = module.ai_workshop_eks_cluster.cluster_name
  cluster_ca_certificate                = module.ai_workshop_eks_cluster.cluster_ca_certificate
  cluster_autoscaler_iam_role_arn       = module.ai_workshop_eks_cluster.cluster_autoscaler_iam_role_arn
  load_balancer_controller_iam_role_arn = module.ai_workshop_eks_cluster.load_balancer_controller_iam_role_arn
  cluster_endpoint                      = module.ai_workshop_eks_cluster.cluster_endpoint
  ai_workshop_domain_name               = var.ai_workshop_domain_name
  ai_workshop_route53_zone_name         = var.ai_workshop_route53_zone_name
  ai_workshop_docker_registry_username  = var.ai_workshop_docker_registry_username
  ai_workshop_docker_registry_password  = var.ai_workshop_docker_registry_password
  ssh_private_key                       = var.ssh_private_key
  ai_workshop_shared_password           = var.ai_workshop_shared_password
  ai_workshop_materials_git_repo_url    = var.ai_workshop_materials_git_repo_url
  openai_api_key                        = var.openai_api_key
  number_of_users                       = var.number_of_users
}
