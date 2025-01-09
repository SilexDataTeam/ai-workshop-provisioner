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

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
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

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
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
  version = "5.52.1"

  role_name_prefix   = "${var.ai_workshop_eks_cluster_name}-load-balancer-controller-"
  policy_name_prefix = "${var.ai_workshop_eks_cluster_name}-load-balancer-controller-"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.ai_workshop_eks_cluster_oidc_provider.arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

module "cluster_autoscaler_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.1"

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
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.1"

  role_name_prefix   = "${var.ai_workshop_eks_cluster_name}-ebs-csi-"
  policy_name_prefix = "${var.ai_workshop_eks_cluster_name}-ebs-csi-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.ai_workshop_eks_cluster_oidc_provider.arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
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
