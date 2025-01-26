resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
  }
}
resource "kubernetes_service_account" "vault" {
  metadata {
    name      = "vault-sa"
    namespace = kubernetes_namespace.vault.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn"     = aws_iam_role.vault_role.arn
      "meta.helm.sh/release-namespace" = kubernetes_namespace.vault.metadata[0].name
    }

    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }
}
resource "aws_iam_role" "vault_role" {
  name = "${var.app_name}-vault-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          "Federated" : var.oidc_provider
        }
        Condition = {
          StringEquals = {
            "${var.eks_issuer}:sub" = "system:serviceaccount:${kubernetes_namespace.vault.metadata[0].name}:vault-sa"
          }
        }
      }
    ]
  })
}
resource "aws_iam_policy" "vault_kms_policy" {
  name = "${var.app_name}VaultKMS"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.vault_kms_key.arn
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "vault_policy_attach" {
  role       = aws_iam_role.vault_role.name
  policy_arn = aws_iam_policy.vault_kms_policy.arn
}
resource "aws_kms_key" "vault_kms_key" {
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms_policy.json

}
data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "kms_policy" {
  statement {
    sid    = "root"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "vault"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.vault_role.arn]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}
resource "random_string" "suffix" {
  length  = 8
  upper   = false
  special = false
}
