variable "name" {
  type = string
}

variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "pods_cidr" {
  type    = string
  default = "10.64.0.0/14"
}

variable "services_cidr" {
  type    = string
  default = "10.68.0.0/20"
}

variable "repository" {
  type = string
}

variable "keep_images" {
  type    = number
  default = 20
}

variable "buckets" {
  type = map(object({
    service = string
    account = string
    public  = bool
  }))

  default = {}
}

variable "backup_bucket" {
  type = string
}

variable "admin_cidrs" {
  type    = list(string)
  default = []
}

variable "cluster_name" {
  type = string
}

variable "node_type" {
  type = string
}

variable "node_disk_gb" {
  type = number
}

variable "node_min" {
  type = number
}

variable "node_max" {
  type = number
}

variable "databases" {
  type = map(object({
    version = string
    user    = string
  }))

  default = {}
}

variable "database_passwords" {
  type      = map(string)
  sensitive = true
  default   = {}
}

variable "db_tier" {
  type = string
}

variable "db_disk_gb" {
  type = number
}

variable "db_backup_days" {
  type = number
}

variable "db_multi_az" {
  type = bool
}

variable "k8s_namespace" {
  type = string
}

variable "backup_accounts" {
  type    = map(string)
  default = {}
}
