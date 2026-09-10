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

variable "ec2_type" {
  type = string
}

variable "ec2_disk_gb" {
  type = number
}

variable "ec2_ubuntu" {
  type    = string
  default = "24.04"
}

variable "admin_cidrs" {
  type = list(string)
}

variable "ssh_public_key" {
  type    = string
  default = ""
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

variable "database_passwords" {
  type      = map(string)
  sensitive = true
  default   = {}
}
