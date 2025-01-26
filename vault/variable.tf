variable "app_name" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "vault_version" {
  type = string
}
variable "public_subnets" {
  type = list(string)
}
variable "alb_cert_arn" {
  type = string
}
variable "eks_issuer" {
  type = string
}
variable "oidc_provider" {
  type = string
}
