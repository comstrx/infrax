variable "name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "storage" {
  type    = map(string)
  default = {}
}

variable "backup_bucket_arn" {
  type = string
}

variable "backup_accounts" {
  type    = list(string)
  default = []
}
