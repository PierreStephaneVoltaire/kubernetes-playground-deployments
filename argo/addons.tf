
module "eks_blueprints_addons" {
  source               = "aws-ia/eks-blueprints-addons/aws"
  version              = "~> 1.0"
  cluster_name         = var.cluster_name
  cluster_endpoint     = var.cluster_endpoint
  cluster_version      = var.cluster_version
  oidc_provider_arn    = var.oidc_provider_arn
  enable_argocd        = true
  enable_argo_rollouts = true
  enable_argo_events   = true
  argocd = {
    chart_version    = "7.7.23"
    create_namespace = true
    values = [templatefile("${path.module}/argo.yaml",
      { domain           = var.argo_domain,
        cert             = var.wildcard_cert,
        subnets          = join(",", var.public_subnets),
        cognito_endpoint = var.cognito_endpoint
        client_id        = var.argo_app_client_id
        client_secret    = var.argo_app_client_secret
    })]

  }
}

resource "kubernetes_cluster_role_binding" "argocd_admin" {
  metadata {
    name = "argocd-crossplane-clusterrolebinding"
  }

  role_ref {
    kind     = "ClusterRole"
    name     = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argocd-application-controller"
    namespace = "argocd"
  }
}
