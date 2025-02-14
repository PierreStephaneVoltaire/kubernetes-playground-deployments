locals {
  argo_sdk_auth_json = jsonencode({
    clientId                        = azuread_application.argo.client_id
    clientSecret                    = azuread_service_principal_password.argo.value
    subscriptionId                   = data.azurerm_client_config.current.subscription_id
    tenantId                         = data.azurerm_client_config.current.tenant_id
    activeDirectoryEndpointUrl       = "https://login.microsoftonline.com"
    resourceManagerEndpointUrl       = "https://management.azure.com/"
    activeDirectoryGraphResourceId   = "https://graph.windows.net/"
    sqlManagementEndpointUrl         = "https://management.core.windows.net:8443/"
    galleryEndpointUrl               = "https://gallery.azure.com/"
    managementEndpointUrl            = "https://management.core.windows.net/"
  })
}

data "azurerm_client_config" "current" {}

resource "azuread_application" "argo" {
  display_name = "argo"
}

resource "azuread_service_principal" "argo" {
  client_id = azuread_application.argo.client_id
}

resource "azuread_service_principal_password" "argo" {
  service_principal_id = azuread_service_principal.argo.id
}

resource "azurerm_role_assignment" "rbac" {
  principal_id        = azuread_service_principal.argo.object_id
  role_definition_name = "Owner"
  scope               = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

resource "aws_kms_key" "argo_secrets_kms" {
  description             = "KMS key for encrypting argo SDK auth secrets"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "argo_secrets_kms_alias" {
  name          = "alias/argo-secrets-kms"
  target_key_id = aws_kms_key.argo_secrets_kms.id
}

resource "aws_secretsmanager_secret" "argo_sdk_auth" {
  name       = "argo-sdk-auth"
  kms_key_id = aws_kms_key.argo_secrets_kms.id
}

resource "aws_secretsmanager_secret_version" "argo_sdk_auth" {
  secret_id     = aws_secretsmanager_secret.argo_sdk_auth.id
  secret_string = local.argo_sdk_auth_json
}

resource "kubernetes_secret" "argo_creds" {
  metadata {
    name = "argo-secret"
    namespace = "argocd"
  }

  data =   {"argo-auth.json" =  local.argo_sdk_auth_json}

  type = "Opaque"
}

