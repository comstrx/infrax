variable "namespace" {
  type = string
}

variable "workload_pool" {
  type = string
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

variable "backup_accounts" {
  type    = map(string)
  default = {}
}
