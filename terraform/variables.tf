variable "ai_workshop_eks_cluster_name" {
  type = string
}

variable "ai_workshop_eks_subnets" {
  type = list(string)
}

variable "ai_workshop_shared_password" {
  type = string
}

variable "ai_workshop_domain_name" {
  type = string
}

variable "ai_workshop_route53_zone_name" {
  type = string
}

variable "number_of_users" {
  type    = number
  default = 30
}

variable "user_prefix" {
  type    = string
  default = "user"
}
