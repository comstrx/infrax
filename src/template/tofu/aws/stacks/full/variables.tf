variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "az_count" {
  type = number
}

variable "cluster_name" {
  type = string
}

variable "k8s_version" {
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

variable "node_desired" {
  type = number
}

variable "node_max" {
  type = number
}

variable "node_max_pods" {
  type    = number
  default = 110
}

variable "repositories" {
  type = list(string)
}

variable "keep_images" {
  type = number
}

variable "buckets" {
  type = map(object({
    service = string
    public  = bool
  }))

  default = {}
}

variable "backup_bucket" {
  type = string
}

variable "databases" {
  type = map(object({
    engine  = string
    version = string
    port    = number
    user    = string
  }))

  default = {}
}

variable "database_passwords" {
  type      = map(string)
  sensitive = true
  default   = {}
}

variable "db_instance_class" {
  type = string
}

variable "db_disk_gb" {
  type = number
}

variable "db_max_disk_gb" {
  type = number
}

variable "db_backup_days" {
  type = number
}

variable "db_multi_az" {
  type = bool
}

variable "db_replicas" {
  type    = number
  default = 0
}

variable "db_apply_now" {
  type    = bool
  default = false
}

variable "db_alarm_cpu" {
  type    = number
  default = 85
}

variable "db_alarm_free_gb" {
  type    = number
  default = 5
}

variable "k8s_namespace" {
  type = string
}

variable "backup_accounts" {
  type    = list(string)
  default = []
}

variable "edge_fixed_ips" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type = number
}

variable "alarm_email" {
  type = string
}
