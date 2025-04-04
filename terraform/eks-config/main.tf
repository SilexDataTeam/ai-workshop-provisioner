locals {
  allowed_users = [
    for i in range(1, var.number_of_users + 1) : "${var.user_prefix}${i}"
  ]
}

provider "kubernetes" {
  alias                  = "ai-workshop"
  host                   = var.cluster_endpoint
  cluster_ca_certificate = var.cluster_ca_certificate
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.ai_workshop_eks_cluster_name]
    command     = "aws"
  }
}

resource "kubernetes_service_account" "ai_workshop_eks_cluster_aws_load_balancer_controller_service_account" {
  provider = kubernetes.ai-workshop
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = var.load_balancer_controller_iam_role_arn
    }
  }
}

provider "helm" {
  alias = "ai-workshop"
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = var.cluster_ca_certificate
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.ai_workshop_eks_cluster_name]
      command     = "aws"
    }
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
    value = var.ai_workshop_eks_cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.ai_workshop_eks_cluster_aws_load_balancer_controller_service_account.metadata.0.name
  }
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

resource "helm_release" "ai_workshop_eks_cluster_autoscaler_helm_release" {
  provider   = helm.ai-workshop
  name       = "cluster-autoscaler"
  chart      = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  namespace  = "kube-system"
  set {
    name  = "autoDiscovery.clusterName"
    value = var.ai_workshop_eks_cluster_name
  }
  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.cluster_autoscaler_iam_role_arn
  }
}

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
}

# Create an ACM certificate
resource "aws_acm_certificate" "jupyterhub_cert" {
  domain_name       = var.ai_workshop_domain_name
  validation_method = "DNS"
  tags = {
    Name = var.ai_workshop_domain_name
  }
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
      openai_api_key             = var.openai_api_key,
      tavily_api_key             = var.tavily_api_key,
      hf_token                   = var.hf_token
    })
  ]

  depends_on = [helm_release.ai_workshop_eks_cluster_autoscaler_helm_release,
    helm_release.ai_workshop_eks_cluster_aws_load_balancer_controller_helm_release,
    helm_release.ai_workshop_eks_cluster_nvidia_device_plugin_helm_release,
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
  depends_on = [kubernetes_namespace.jupyterhub]
}

# Retrieve the Ingress resource to get the ALB hostname
data "kubernetes_ingress_v1" "jupyterhub_ingress" {
  provider = kubernetes.ai-workshop
  metadata {
    name      = "jupyterhub"
    namespace = "jupyterhub"
  }
  depends_on = [helm_release.ai_workshop_jupyterhub]
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

resource "kubernetes_deployment" "workshop_user_registration" {
  provider = kubernetes.ai-workshop
  metadata {
    name      = "workshop-user-registration"
    namespace = "jupyterhub"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "workshop-user-registration"
      }
    }

    template {
      metadata {
        labels = {
          app = "workshop-user-registration"
        }
      }

      spec {
        container {
          image = "ghcr.io/silexdatateam/ai-workshop-provisioner/workshop-user-registration:main"
          name  = "workshop-user-registration"
          port {
            container_port = 3000
          }
          env {
            name  = "MAX_USERS"
            value = var.number_of_users
          }
          env {
            name  = "SHARED_SECRET"
            value = var.ai_workshop_shared_password
          }
          env {
            name  = "CSV_FILE_PATH"
            value = "/workspace/workshop-user-registration/registration.csv"
          }
        }
        image_pull_secrets {
          name = kubernetes_secret.ghcr_secret.metadata[0].name
        }
      }
    }
  }
}

resource "kubernetes_service" "workshop_user_registration" {
  provider = kubernetes.ai-workshop
  metadata {
    name      = "workshop-user-registration"
    namespace = "jupyterhub"
  }

  spec {
    selector = {
      app = "workshop-user-registration"
    }

    port {
      port        = 3000
      target_port = 3000
    }

    type = "NodePort"
  }
}

resource "aws_acm_certificate" "workshop_user_registration_cert" {
  domain_name       = "ai-workshop-registration.${var.ai_workshop_route53_zone_name}"
  validation_method = "DNS"
  tags = {
    Name = "ai-workshop-registration.${var.ai_workshop_route53_zone_name}"
  }
}

resource "aws_route53_record" "workshop_user_registration_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.workshop_user_registration_cert.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "workshop_user_registration_cert_validation" {
  certificate_arn         = aws_acm_certificate.workshop_user_registration_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.workshop_user_registration_cert_validation : record.fqdn]
}

resource "kubernetes_ingress_v1" "workshop_user_registration" {
  provider = kubernetes.ai-workshop
  metadata {
    name      = "workshop-user-registration"
    namespace = "jupyterhub"
    annotations = {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/"
      "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
      "alb.ingress.kubernetes.io/success-codes"    = "200"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn"  = aws_acm_certificate_validation.workshop_user_registration_cert_validation.certificate_arn
    }
  }

  spec {
    rule {
      host = "ai-workshop-registration.${var.ai_workshop_route53_zone_name}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.workshop_user_registration.metadata[0].name
              port {
                number = kubernetes_service.workshop_user_registration.spec[0].port[0].port
              }
            }
          }
        }
      }
    }
  }

  wait_for_load_balancer = true
}

data "kubernetes_ingress_v1" "workshop_user_registration" {
  provider = kubernetes.ai-workshop
  metadata {
    name      = "workshop-user-registration"
    namespace = "jupyterhub"
  }

  depends_on = [kubernetes_ingress_v1.workshop_user_registration, helm_release.ai_workshop_eks_cluster_aws_load_balancer_controller_helm_release]
}


resource "aws_route53_record" "workshop_user_registration" {
  zone_id    = data.aws_route53_zone.zone.zone_id
  name       = "ai-workshop-registration.${var.ai_workshop_route53_zone_name}"
  type       = "CNAME"
  ttl        = 300
  records    = [data.kubernetes_ingress_v1.workshop_user_registration.status.0.load_balancer.0.ingress.0.hostname]
  depends_on = [data.kubernetes_ingress_v1.workshop_user_registration]
}
