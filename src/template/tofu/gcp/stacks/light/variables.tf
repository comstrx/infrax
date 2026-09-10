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

variable "machine_type" {
  type = string
}

variable "disk_gb" {
  type = number
}

variable "image" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "ssh_public_key" {
  type    = string
  default = ""
}

variable "database_passwords" {
  type      = map(string)
  sensitive = true
  default   = {}
}
