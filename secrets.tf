resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

resource "aws_iam_role" "secret-sa" {
  name               =  "external-secrets-irsa"
  assume_role_policy = data.aws_iam_policy_document.secrets.json
}

data "aws_iam_policy_document" "secrets" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.eks.outputs.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      values   = ["system:serviceaccount:external-secrets:external-secrets-sa"]
      variable = "${data.terraform_remote_state.eks.outputs.oidc_provider}:sub"
    }
    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = "${data.terraform_remote_state.eks.outputs.oidc_provider}:aud"
    }
  }
}

resource "aws_iam_policy" "secrets" {

  name = "${var.app_name}-ExternalSecretsPolicy"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      Statement = [
        {
          Effect   = "Allow"
          Action   =  [
            "ssm:GetParameter*",
            "ssm:PutParameter*",
            "ssm:AddTagsToResource",
            "ssm:ListTagsForResource"
          ]
          Resource = "*"
        },
        {
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = "*"
        }
      ]
    }
  )
}

resource "aws_iam_policy_attachment" "secret" {
  name   = "secrets"
  roles = [aws_iam_role.secret-sa.name]
  policy_arn = aws_iam_policy.secrets.arn
}

resource "kubernetes_service_account" "external-secrets-sa"{
  metadata {
    name      =  "external-secrets-sa"
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn"     = aws_iam_role.secret-sa.arn
      "meta.helm.sh/release-namespace" =  kubernetes_namespace.external_secrets.metadata[0].name
    }
  }
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets"

  values = [<<EOF
serviceAccount:
  create: false
  name: "external-secrets-sa"
EOF
  ]
}
resource "aws_ssm_parameter" "alb_certificate_arn" {
  name  = "/secrets/alb-certificate-arn"
  type  = "SecureString"
  value =  data.terraform_remote_state.network.outputs.domain_acm_certificate_arn
}
resource "aws_ssm_parameter" "subnets" {
  name  = "/secrets/subnets"
  type  = "SecureString"
  value =  join(",",data.terraform_remote_state.network.outputs.public_subnets)
}

resource "kubernetes_manifest" "cluster_secret_store" {
  count = 1
  depends_on = [helm_release.external_secrets]
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secret-store"
    }
    spec = {
      provider = {
        aws = {
          service = "ParameterStore"
          region  = data.aws_region.current.name
          auth = {
            jwt = {
              serviceAccountRef = {
                name = kubernetes_service_account.external-secrets-sa.metadata[0].name
                namespace: kubernetes_namespace.external_secrets.metadata[0].name

              }
            }
          }
        }
      }
    }
  }
}
