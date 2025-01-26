resource "aws_iam_role" "jenkins_service_account_role" {
  name               = "eks-jenkins-service-account-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume_policy.json
}

data "aws_iam_policy_document" "jenkins_assume_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_arn}:sub"
      values   = ["system:serviceaccount:jenkins:jenkins-service-account"]
    }
  }
}
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
}
resource "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins-service-account"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.jenkins_service_account_role.arn
    }
  }
}

resource "kubernetes_secret" "jenkins_auth" {
  metadata {
    name      = "jenkinsoauth"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  data = { JENKINS_OAUTH_USER_INFO_URI = base64encode("https://${var.cognito_uri}/oauth2/userInfo"),
    JENKINS_OAUTH_AUTHORIZATION_URI = base64encode("https://${var.cognito_uri}/oauth2/authorize"),
    JENKINS_OAUTH_TOKEN_URI         = base64encode("https://${var.cognito_uri}/oauth2/token"),
    JENKINS_OAUTH_CLIENT_ID         = base64encode(kubernetes_namespace.jenkins.metadata[0].name),
    JENKINS_OAUTH_CLIENT_SECRET     = base64encode(var.client_secret),
  }

  type = "Opaque"
}



resource "kubernetes_manifest" "jenkins_argocd_application" {
  depends_on = [kubernetes_secret.jenkins_auth]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "jenkins"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://charts.jenkins.io"
        targetRevision = "5.8.5"
        chart          = "jenkins"
        helm = {
          valueFiles = [var.jenkins_git_values]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.jenkins.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }
}
