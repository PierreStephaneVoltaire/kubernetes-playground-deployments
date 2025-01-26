
data "aws_region" "current" {}
resource "helm_release" "vault" {
  name             = "vault"
  namespace        = kubernetes_namespace.vault.metadata[0].name
  create_namespace = false
  chart            = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  version          = var.vault_version
  cleanup_on_fail  = true
  set {
    name  = "server.serviceAccount.create"
    value = "false"
  }
  values = [
    templatefile("${path.module}/vault.yaml",
      { domain_name           = var.domain_name,
        public_subnets_string = join(",", var.public_subnets),
        alb_cert_arn          = var.alb_cert_arn,
        region                = data.aws_region.current.name
        sa                    = kubernetes_service_account.vault.metadata[0].name
        key                   = aws_kms_key.vault_kms_key.arn
    })
  ]
}
