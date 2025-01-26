terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.8"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "> 1.16.0"

    }
  }
  required_version = ">= 1.3.0"
}

data "aws_region" "current" {}

data "terraform_remote_state" "auth" {
  backend = "s3"
  config = {
    bucket = var.bucket
    key    = var.auth_key
    region = data.aws_region.current.name
  }
}
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = var.bucket
    key    = var.eks_key
    region = data.aws_region.current.name
  }
}
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.bucket
    key    = var.network_key
    region = data.aws_region.current.name
  }
}
data "aws_route53_zone" "main" {
  name = var.domain_name
}

module "argo" {
  source                 = "./argo"
  argo_app_client_id     = data.terraform_remote_state.auth.outputs.argo_app_client_id
  argo_app_client_secret = data.terraform_remote_state.auth.outputs.argo_app_client_secret
  argo_domain            = "argocd.${var.domain_name}"
  aws_route53_zone_arn   = data.aws_route53_zone.main.arn
  cluster_endpoint       = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_name           = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_version        = data.terraform_remote_state.eks.outputs.cluster_version
  cognito_endpoint       = data.terraform_remote_state.auth.outputs.cognito_endpoint
  oidc_provider          = data.terraform_remote_state.eks.outputs.oidc_provider
  oidc_provider_arn      = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  public_subnets         = data.terraform_remote_state.network.outputs.public_subnets
  wildcard_cert          = data.terraform_remote_state.network.outputs.domain_acm_certificate_arn
}
module "jenkins" {
  source             = "./jenkins"
  client_id          = data.terraform_remote_state.auth.outputs.jenkins_app_client_id
  client_secret      = data.terraform_remote_state.auth.outputs.jenkins_app_client_secret
  cognito_uri        = data.terraform_remote_state.auth.outputs.cognito_endpoint
  jenkins_git_values = var.jenkins_git_values
  oidc_provider_arn  = data.terraform_remote_state.eks.outputs.oidc_provider_arn
}