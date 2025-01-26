variable "client_id" {
  type = string
}
variable "client_secret" {
  type = string
}
variable "cognito_uri" {
  type = string
}
variable "oidc_provider_arn" {
  type = string
}
variable "jenkins_git_values" {
  type = string
}
variable "certificate-arn" {
  type = string
}
variable "subnets" {
  type = list(string)
}
variable "cluster_endpoint" {
  type = string
}