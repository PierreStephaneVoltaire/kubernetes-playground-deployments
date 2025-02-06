variable "app_name" {
  type    = string
  default = "infra"
}
variable "tags" {
  type = map(string)
}
variable "domain_name" {
  type = string
}

variable "cluster_service_ipv4_cidr" {
  type = string
}
variable "vpc_public_subnet_cidr" {
  type    = list(string)
  default = []
}
variable "vpc_private_subnet_cidr" {
  type    = list(string)
  default = []
}
variable "vpc_azs" {
  type    = list(string)
  default = []
}
variable "vpc_cdr" {
  type = string
}

variable "cluster_version" {
  type = string
}
variable "contact" {
  type = string
}
variable "eks_managed_node_groups" {
  type = map(object({
    disk_size     = number
    capacity_type = string
    min_size      = number
    max_size      = number
    desired_size  = number
  }))
}

variable "allowed_ips" {
  type      = list(string)
  sensitive = true
}
variable "users" {
  type = map(object({ email = string }))
}


variable "jenkins_git_values" {
  type = string
}
variable "bucket" {
  type = string
}
variable "auth_key" {
  type = string
}
variable "eks_key" {
  type = string
}
variable "network_key" {
  type = string
}

variable "github_username" {
  type = string
}