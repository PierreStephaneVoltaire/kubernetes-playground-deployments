resource "aws_s3_bucket" "loki_logs" {
  bucket = "${var.app_name}-loki-logs-bucket"
}
resource "aws_kms_key" "loki_s3_key" {
  description             = "KMS key for Loki S3 encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}
resource "aws_s3_bucket_server_side_encryption_configuration" "loki_encryption" {
  bucket = aws_s3_bucket.loki_logs.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.loki_s3_key.id
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_secret" "loki_creds" {
  count = length(var.htpasswd)>0?1:0
  metadata {
    name      = "loki-basic-auth"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  data = {
    ".htpasswd" = base64encode(var.htpasswd)
  }
  type = "Opaque"

}
resource "kubernetes_secret" "canary_creds" {
  count = length(var.loki_username)>0 &&  length(var.loki_password)>0 ?1:0
  metadata {
    name      = "canary-basic-auth"
    namespace =  kubernetes_namespace.monitoring.metadata[0].name
  }
  data = {
    "username" = base64encode(var.loki_username)
    "password" = base64encode(var.loki_password)

  }
  type = "Opaque"

}


resource "aws_iam_role" "sa" {
  count = length(var.htpasswd)>0?1:0
  name               = "${var.app_name}-loki"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy[0].json
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  count = length(var.htpasswd)>0?1:0
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.eks.outputs.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      values   = ["system:serviceaccount:monitoring:loki-service-account"]
      variable = "${data.terraform_remote_state.eks.outputs.oidc_provider}:sub"
    }
    condition {
      test     = "StringEquals"
      values   = ["sts.amazonaws.com"]
      variable = "${data.terraform_remote_state.eks.outputs.oidc_provider}:aud"
    }
  }
}

resource "aws_iam_policy" "policy" {
  count = length(var.htpasswd)>0?1:0

  name = "${var.app_name}-loki"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:*",
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:GenerateDataKey",
            "kms:DescribeKey",
            "iam:PassRole"
          ],
          "Resource" : "*"
        }
      ]
    }
  )
}

resource "aws_iam_policy_attachment" "loki" {
  count = length(var.htpasswd)>0?1:0

  name   = "s3"
  roles = [aws_iam_role.sa[0].name]
  policy_arn = aws_iam_policy.policy[0].arn
}

resource "kubernetes_service_account" "sa" {
  count = length(var.htpasswd)>0?1:0
  metadata {
    name      = "loki-service-account"
    namespace =  kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn"     = aws_iam_role.sa[0].arn
      "meta.helm.sh/release-namespace" =  kubernetes_namespace.monitoring.metadata[0].name
    }
  }
}


resource "kubernetes_manifest" "external_secret_cert" {
  count = 1
  depends_on = [kubernetes_manifest.cluster_secret_store]
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "alb-certificate-secret"
      namespace =  kubernetes_namespace.monitoring.metadata[0].name
    }
    spec = {
      secretStoreRef = {
        name = "aws-secret-store"
        kind = "ClusterSecretStore"
      }
      target = {
        name            = "alb-certificate"
        creationPolicy  = "Owner"
      }
      data = [{
        secretKey = "certificate-arn"
        remoteRef = {
          key = aws_ssm_parameter.alb_certificate_arn.name
        }
      }]
    }
  }
}

resource "kubernetes_manifest" "external_secret_subnets" {
  count = 1
  depends_on = [kubernetes_manifest.cluster_secret_store]
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "subnets-secret"
      namespace =  kubernetes_namespace.monitoring.metadata[0].name
    }
    spec = {
      secretStoreRef = {
        name = "aws-secret-store"
        kind = "ClusterSecretStore"
      }
      target = {
        name            = "subnets"
        creationPolicy  = "Owner"
      }
      data = [{
        secretKey = "subnets"
        remoteRef = {
          key = aws_ssm_parameter.subnets.name
        }
      }]
    }
  }
}

