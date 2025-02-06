variable "oidc_provider" {
  type = string
}
variable "cluster_name" {
  type = string
}
variable "cluster_endpoint" {
  type = string
}
variable "cluster_version" {
  type = string
}
variable "oidc_provider_arn" {
  type = string
}
variable "wildcard_cert" {
  type = string
}
variable "cognito_endpoint" {
  type = string
}
variable "argo_app_client_id" {
  type = string
}
variable "argo_app_client_secret" {
  type = string
}
variable "public_subnets" {
  type = list(string)
}
variable "aws_route53_zone_arn" {
  type = string
}
variable "argo_domain" {
  type = string
}
variable "token" {
  type = string
}
variable "caData" {
  type = string
}
