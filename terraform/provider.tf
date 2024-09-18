# use aws s3 for terraform state
terraform {
  backend "s3" {
    bucket = "dlewis-lab-tf-state-bucket"
    key    = "ai-workshop.tfstate"
    region = "us-east-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.67.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.32.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.15.0"
    }
  }
}

# use aws provider
provider "aws" {
  region = "us-east-1"
}

provider "tls" {

}
