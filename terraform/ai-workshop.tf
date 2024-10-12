locals {
  allowed_users = [
    for i in range(1, var.number_of_users + 1) : "${var.user_prefix}${i}"
  ]
}

resource "aws_iam_role" "ai_workshop_eks_cluster_role" {
  name               = "${var.ai_workshop_eks_cluster_name}-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ai_workshop_eks_cluster_AWSEKSClusterPolicy" {
  role       = aws_iam_role.ai_workshop_eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "ai_workshop_eks_cluster_AWSEKSVPCResourceController" {
  role       = aws_iam_role.ai_workshop_eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_kms_key" "ai_workshop_eks_cluster" {
  description             = "KMS key for ${var.ai_workshop_eks_cluster_name}"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_cloudwatch_log_group" "ai_workshop_eks_cluster_log_group" {
  name              = "/aws/eks/${var.ai_workshop_eks_cluster_name}/cluster"
  retention_in_days = 7
}

resource "aws_eks_cluster" "ai_workshop_eks_cluster" {
  name     = var.ai_workshop_eks_cluster_name
  role_arn = aws_iam_role.ai_workshop_eks_cluster_role.arn

  vpc_config {
    subnet_ids              = var.ai_workshop_eks_subnets
    endpoint_private_access = true
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.ai_workshop_eks_cluster.arn
    }
    resources = ["secrets"]
  }

  #enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  enabled_cluster_log_types = []
  depends_on = [aws_iam_role_policy_attachment.ai_workshop_eks_cluster_AWSEKSClusterPolicy,
  aws_iam_role_policy_attachment.ai_workshop_eks_cluster_AWSEKSVPCResourceController, aws_cloudwatch_log_group.ai_workshop_eks_cluster_log_group]
}

data "aws_iam_role" "ai_workshop_gh_actions_role" {
  name = "gh-terraform-deployment-role"
}

resource "aws_eks_access_entry" "gh_terraform_deployment_eks_access_entry" {
  cluster_name  = aws_eks_cluster.ai_workshop_eks_cluster.name
  principal_arn = data.aws_iam_role.ai_workshop_gh_actions_role.arn
}

resource "aws_eks_access_policy_association" "gh_terraform_deployment_eks_access_policy_association" {
  cluster_name  = aws_eks_cluster.ai_workshop_eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.aws_iam_role.ai_workshop_gh_actions_role.arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "aws_administrator_access_eks_access_entry" {
  cluster_name  = aws_eks_cluster.ai_workshop_eks_cluster.name
  principal_arn = var.aws_administrator_role_arn
}

resource "aws_eks_access_policy_association" "aws_administrator_access_eks_access_policy_association" {
  cluster_name  = aws_eks_cluster.ai_workshop_eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = var.aws_administrator_role_arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_iam_role" "ai_workshop_eks_cluster_cpu_node_group_1_role" {
  name               = "${var.ai_workshop_eks_cluster_name}-cpu-node-group-1-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ai_workshop_eks_cluster_cpu_node_group_1_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.ai_workshop_eks_cluster_cpu_node_group_1_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ai_workshop_eks_cluster_cpu_node_group_1_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.ai_workshop_eks_cluster_cpu_node_group_1_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ai_workshop_eks_cluster_cpu_node_group_1_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.ai_workshop_eks_cluster_cpu_node_group_1_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_node_group" "ai_workshop_eks_cluster_cpu_node_group_1" {
  cluster_name    = var.ai_workshop_eks_cluster_name
  node_group_name = "cpu-node-group-1"
  node_role_arn   = aws_iam_role.ai_workshop_eks_cluster_cpu_node_group_1_role.arn
  subnet_ids      = var.ai_workshop_eks_subnets

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  disk_size = 50

  ami_type = "AL2_x86_64"

  instance_types = ["m5.xlarge"]

  depends_on = [aws_eks_cluster.ai_workshop_eks_cluster, aws_iam_role_policy_attachment.ai_workshop_eks_cluster_cpu_node_group_1_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.ai_workshop_eks_cluster_cpu_node_group_1_AmazonEC2ContainerRegistryReadOnly,
  aws_iam_role_policy_attachment.ai_workshop_eks_cluster_cpu_node_group_1_AmazonEKS_CNI_Policy]
}

resource "aws_iam_role_policy_attachment" "ai_workshop_eks_cluster_cpu_node_group_1_CloudWatchAgentServerPolicy" {
  role       = aws_iam_role.ai_workshop_eks_cluster_cpu_node_group_1_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ai_workshop_eks_cluster_cpu_node_group_1_AWSXrayWriteOnlyAccess" {
  role       = aws_iam_role.ai_workshop_eks_cluster_cpu_node_group_1_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_iam_role" "ai_workshop_eks_cluster_gpu_node_group_1_role" {
  name               = "${var.ai_workshop_eks_cluster_name}-gpu-node-group-1-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ai_workshop_eks_cluster_gpu_node_group_1_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.ai_workshop_eks_cluster_gpu_node_group_1_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ai_workshop_eks_cluster_gpu_node_group_1_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.ai_workshop_eks_cluster_gpu_node_group_1_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ai_workshop_eks_cluster_gpu_node_group_1_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.ai_workshop_eks_cluster_gpu_node_group_1_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_node_group" "ai_workshop_eks_cluster_gpu_node_group_1" {
  cluster_name    = var.ai_workshop_eks_cluster_name
  node_group_name = "gpu-node-group-1"
  node_role_arn   = aws_iam_role.ai_workshop_eks_cluster_gpu_node_group_1_role.arn
  subnet_ids      = var.ai_workshop_eks_subnets

  scaling_config {
    desired_size = 0
    max_size     = var.number_of_users
    min_size     = 0
  }

  disk_size = 200

  ami_type = "AL2_x86_64_GPU"

  instance_types = ["g5.2xlarge"]

  depends_on = [aws_eks_cluster.ai_workshop_eks_cluster, aws_iam_role_policy_attachment.ai_workshop_eks_cluster_gpu_node_group_1_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.ai_workshop_eks_cluster_gpu_node_group_1_AmazonEC2ContainerRegistryReadOnly,
  aws_iam_role_policy_attachment.ai_workshop_eks_cluster_gpu_node_group_1_AmazonEKS_CNI_Policy]
}

resource "aws_iam_role_policy_attachment" "ai_workshop_eks_cluster_gpu_node_group_1_CloudWatchAgentServerPolicy" {
  role       = aws_iam_role.ai_workshop_eks_cluster_gpu_node_group_1_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ai_workshop_eks_cluster_gpu_node_group_1_AWSXrayWriteOnlyAccess" {
  role       = aws_iam_role.ai_workshop_eks_cluster_gpu_node_group_1_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

data "tls_certificate" "ai_workshop_eks_cluster_oidc_certificate" {
  url = aws_eks_cluster.ai_workshop_eks_cluster.identity.0.oidc.0.issuer
}

resource "aws_iam_openid_connect_provider" "ai_workshop_eks_cluster_oidc_provider" {
  url             = aws_eks_cluster.ai_workshop_eks_cluster.identity.0.oidc.0.issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.ai_workshop_eks_cluster_oidc_certificate.certificates.0.sha1_fingerprint]
}

module "load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.46.0"

  role_name_prefix   = "${var.ai_workshop_eks_cluster_name}-load-balancer-controller-"
  policy_name_prefix = "${var.ai_workshop_eks_cluster_name}-load-balancer-controller-"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.ai_workshop_eks_cluster_oidc_provider.arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  depends_on = [aws_eks_access_entry.aws_administrator_access_eks_access_entry, aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association]
}

data "aws_eks_cluster_auth" "ai_workshop_eks_cluster_auth" {
  name = aws_eks_cluster.ai_workshop_eks_cluster.name

  depends_on = [
    aws_eks_cluster.ai_workshop_eks_cluster,
    ai_workshop_eks_cluster_cpu_node_group_1,
    aws_eks_access_entry.gh_terraform_deployment_eks_access_entry,
    aws_eks_access_policy_association.gh_terraform_deployment_eks_access_policy_association,
    aws_eks_access_entry.aws_administrator_access_eks_access_entry,
    aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association
  ]
}

provider "kubernetes" {
  alias                  = "ai-workshop"
  host                   = aws_eks_cluster.ai_workshop_eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.ai_workshop_eks_cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.ai_workshop_eks_cluster_auth.token
}

resource "kubernetes_service_account" "ai_workshop_eks_cluster_aws_load_balancer_controller_service_account" {
  provider = kubernetes.ai-workshop
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.load_balancer_controller_irsa_role.iam_role_arn
    }
  }
  depends_on = [aws_eks_access_entry.gh_terraform_deployment_eks_access_entry, aws_eks_access_policy_association.gh_terraform_deployment_eks_access_policy_association, aws_eks_access_entry.aws_administrator_access_eks_access_entry, aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association, module.load_balancer_controller_irsa_role]
}

provider "helm" {
  alias = "ai-workshop"
  kubernetes {
    host                   = aws_eks_cluster.ai_workshop_eks_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.ai_workshop_eks_cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.ai_workshop_eks_cluster_auth.token
  }
}

resource "helm_release" "ai_workshop_eks_cluster_aws_load_balancer_controller_helm_release" {
  provider   = helm.ai-workshop
  name       = "aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  namespace  = "kube-system"
  set {
    name  = "clusterName"
    value = aws_eks_cluster.ai_workshop_eks_cluster.name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.ai_workshop_eks_cluster_aws_load_balancer_controller_service_account.metadata.0.name
  }

  depends_on = [aws_eks_node_group.ai_workshop_eks_cluster_cpu_node_group_1, module.load_balancer_controller_irsa_role, aws_eks_access_entry.gh_terraform_deployment_eks_access_entry, aws_eks_access_policy_association.gh_terraform_deployment_eks_access_policy_association, aws_eks_access_entry.aws_administrator_access_eks_access_entry, aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association]
}

resource "aws_s3_bucket" "ai_workshop_logs_bucket" {
  bucket        = "ai-workshop-logs-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "ai_workshop_logs_bucket_public_access_block" {
  bucket = aws_s3_bucket.ai_workshop_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "ai_workshop_logs_bucket_policy_document" {
  statement {
    actions = ["s3:PutObject"]
    effect  = "Allow"

    resources = [
      "${aws_s3_bucket.ai_workshop_logs_bucket.arn}/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::127311923021:root"]
    }
  }
}

resource "aws_s3_bucket_policy" "ai_workshop_logs_bucket_policy" {
  bucket = aws_s3_bucket.ai_workshop_logs_bucket.id
  policy = data.aws_iam_policy_document.ai_workshop_logs_bucket_policy_document.json
}

module "cluster_autoscaler_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.46.0"

  role_name_prefix               = "${var.ai_workshop_eks_cluster_name}-cluster-autoscaler-"
  policy_name_prefix             = "${var.ai_workshop_eks_cluster_name}-cluster-autoscaler-"
  cluster_autoscaler_cluster_ids = [aws_eks_cluster.ai_workshop_eks_cluster.id]

  attach_cluster_autoscaler_policy = true

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.ai_workshop_eks_cluster_oidc_provider.arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler-aws-cluster-autoscaler"]
    }
  }

  depends_on = [aws_eks_access_entry.aws_administrator_access_eks_access_entry, aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association]
}

resource "helm_release" "ai_workshop_eks_cluster_autoscaler_helm_release" {
  provider   = helm.ai-workshop
  name       = "cluster-autoscaler"
  chart      = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  namespace  = "kube-system"
  set {
    name  = "autoDiscovery.clusterName"
    value = aws_eks_cluster.ai_workshop_eks_cluster.name
  }
  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.cluster_autoscaler_irsa_role.iam_role_arn
  }

  depends_on = [aws_eks_node_group.ai_workshop_eks_cluster_cpu_node_group_1, aws_eks_access_entry.gh_terraform_deployment_eks_access_entry, aws_eks_access_policy_association.gh_terraform_deployment_eks_access_policy_association, aws_eks_access_entry.aws_administrator_access_eks_access_entry, aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association]
}

# resource "aws_eks_addon" "ai_workshop_eks_cluster_amazon_cloudwatch_observability" {
#   cluster_name = aws_eks_cluster.ai_workshop_eks_cluster.name
#   addon_name   = "amazon-cloudwatch-observability"

#   depends_on = [helm_release.ai_workshop_eks_cluster_aws_load_balancer_controller_helm_release, helm_release.ai_workshop_eks_cluster_autoscaler_helm_release, aws_cloudwatch_log_group.ai_workshop_eks_cluster_log_group, aws_eks_node_group.ai_workshop_eks_cluster_cpu_node_group_1]
# }

resource "helm_release" "ai_workshop_eks_cluster_nvidia_device_plugin_helm_release" {
  provider   = helm.ai-workshop
  name       = "nvidia-device-plugin"
  chart      = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  namespace  = "kube-system"
  set {
    name  = "gfd.enabled"
    value = "true"
  }
  depends_on = [aws_eks_node_group.ai_workshop_eks_cluster_cpu_node_group_1, aws_eks_access_entry.gh_terraform_deployment_eks_access_entry, aws_eks_access_policy_association.gh_terraform_deployment_eks_access_policy_association, aws_eks_access_entry.aws_administrator_access_eks_access_entry, aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association]
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.46.0"

  role_name_prefix   = "${var.ai_workshop_eks_cluster_name}-ebs-csi-"
  policy_name_prefix = "${var.ai_workshop_eks_cluster_name}-ebs-csi-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.ai_workshop_eks_cluster_oidc_provider.arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  depends_on = [aws_eks_access_entry.aws_administrator_access_eks_access_entry, aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association]
}

resource "aws_eks_addon" "ai_workshop_eks_cluster_aws_ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.ai_workshop_eks_cluster.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
  configuration_values = jsonencode({
    defaultStorageClass = {
      enabled = true
    }
  })
  depends_on = [aws_eks_node_group.ai_workshop_eks_cluster_cpu_node_group_1]
}

# Create an ACM certificate
resource "aws_acm_certificate" "jupyterhub_cert" {
  domain_name       = var.ai_workshop_domain_name
  validation_method = "DNS"
  tags = {
    Name = var.ai_workshop_domain_name
  }

  depends_on = [aws_eks_cluster.ai_workshop_eks_cluster]
}

# Reference your existing Route53 zone
data "aws_route53_zone" "zone" {
  name         = var.ai_workshop_route53_zone_name
  private_zone = false
}

# Create DNS validation records
resource "aws_route53_record" "jupyterhub_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.jupyterhub_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.zone.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# Wait for the certificate to be validated
resource "aws_acm_certificate_validation" "jupyterhub_cert_validation" {
  certificate_arn         = aws_acm_certificate.jupyterhub_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.jupyterhub_cert_validation : record.fqdn]
}

# Define variables for admin and allowed users
variable "admin_users" {
  type    = list(string)
  default = ["adminuser1", "adminuser2"]
}

variable "allowed_users" {
  type    = list(string)
  default = ["user1", "user2", "user3"] # Add all allowed users
}

resource "kubernetes_namespace" "jupyterhub" {
  provider = kubernetes.ai-workshop
  metadata {
    name = "jupyterhub"
  }

  depends_on = [aws_eks_cluster.ai_workshop_eks_cluster, aws_eks_access_entry.gh_terraform_deployment_eks_access_entry, aws_eks_access_policy_association.gh_terraform_deployment_eks_access_policy_association, aws_eks_access_entry.aws_administrator_access_eks_access_entry, aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association]
}

locals {
  docker_registry_secret_json = jsonencode({
    auths = {
      "ghcr.io" = {
        username = var.ai_workshop_docker_registry_username
        password = var.ai_workshop_docker_registry_password
        auth     = base64encode("${var.ai_workshop_docker_registry_username}:${var.ai_workshop_docker_registry_password}")
      }
    }
  })
}

resource "kubernetes_secret" "ghcr_secret" {
  provider = kubernetes.ai-workshop
  metadata {
    name      = "ghcr-secret"
    namespace = "jupyterhub"
  }

  data = {
    ".dockerconfigjson" = local.docker_registry_secret_json
  }

  type = "kubernetes.io/dockerconfigjson"

  depends_on = [kubernetes_namespace.jupyterhub, aws_eks_access_entry.gh_terraform_deployment_eks_access_entry, aws_eks_access_policy_association.gh_terraform_deployment_eks_access_policy_association, aws_eks_access_entry.aws_administrator_access_eks_access_entry, aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association]
}

# Deploy the Helm chart
resource "helm_release" "ai_workshop_jupyterhub" {
  provider         = helm.ai-workshop
  name             = "jupyterhub"
  chart            = "jupyterhub"
  repository       = "https://jupyterhub.github.io/helm-chart/"
  namespace        = "jupyterhub"
  version          = "3.3.8"
  create_namespace = true

  values = [
    templatefile("${path.module}/files/jupyterhub_values.tftpl", {
      admin_users                = var.admin_users
      allowed_users              = local.allowed_users
      dummy_auth_password        = var.ai_workshop_shared_password
      aws_acm_certificate_arn    = aws_acm_certificate_validation.jupyterhub_cert_validation.certificate_arn
      git_deploy_key_secret_name = kubernetes_secret.git_deploy_key.metadata[0].name,
      git_repo_url               = var.ai_workshop_materials_git_repo_url,
    })
  ]

  depends_on = [aws_eks_node_group.ai_workshop_eks_cluster_cpu_node_group_1,
    helm_release.ai_workshop_eks_cluster_autoscaler_helm_release,
    helm_release.ai_workshop_eks_cluster_aws_load_balancer_controller_helm_release,
    helm_release.ai_workshop_eks_cluster_nvidia_device_plugin_helm_release,
    aws_eks_addon.ai_workshop_eks_cluster_aws_ebs_csi_driver,
    aws_eks_access_entry.gh_terraform_deployment_eks_access_entry,
    aws_eks_access_policy_association.gh_terraform_deployment_eks_access_policy_association,
    aws_eks_access_entry.aws_administrator_access_eks_access_entry,
    aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association,
  kubernetes_secret.ghcr_secret]
}

resource "kubernetes_secret" "git_deploy_key" {
  provider = kubernetes.ai-workshop
  metadata {
    name      = "git-deploy-key"
    namespace = "jupyterhub" # Replace with your namespace if different
  }

  data = {
    "id_rsa" = "${var.ssh_private_key}"
  }

  type       = "Opaque"
  depends_on = [kubernetes_namespace.jupyterhub, aws_eks_access_entry.gh_terraform_deployment_eks_access_entry, aws_eks_access_policy_association.gh_terraform_deployment_eks_access_policy_association, aws_eks_access_entry.aws_administrator_access_eks_access_entry, aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association]
}

# Retrieve the Ingress resource to get the ALB hostname
data "kubernetes_ingress_v1" "jupyterhub_ingress" {
  provider = kubernetes.ai-workshop
  metadata {
    name      = "jupyterhub"
    namespace = "jupyterhub"
  }
  depends_on = [helm_release.ai_workshop_jupyterhub, aws_eks_access_entry.gh_terraform_deployment_eks_access_entry, aws_eks_access_policy_association.gh_terraform_deployment_eks_access_policy_association, aws_eks_access_entry.aws_administrator_access_eks_access_entry, aws_eks_access_policy_association.aws_administrator_access_eks_access_policy_association]
}

# output "ingress_hostname" {
#   value = data.kubernetes_ingress_v1.jupyterhub_ingress.status.0.load_balancer.0.ingress.0.hostname
# }

resource "aws_route53_record" "jupyterhub" {
  zone_id    = data.aws_route53_zone.zone.zone_id
  name       = var.ai_workshop_domain_name
  type       = "CNAME"
  ttl        = 300
  records    = [data.kubernetes_ingress_v1.jupyterhub_ingress.status.0.load_balancer.0.ingress.0.hostname]
  depends_on = [data.kubernetes_ingress_v1.jupyterhub_ingress]
}
