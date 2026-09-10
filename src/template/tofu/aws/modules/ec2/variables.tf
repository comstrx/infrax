variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.large"
}

variable "disk_gb" {
  type    = number
  default = 40
}

variable "admin_cidrs" {
  type    = list(string)
  default = []

  validation {
    condition     = alltrue([for cidr in var.admin_cidrs : can(cidrhost(cidr, 0))])
    error_message = "ADMIN_CIDRS must be CIDRs — the networks allowed to reach the kubernetes api."
  }
}

variable "ssh_public_key" {
  type    = string
  default = ""
}

variable "ecr_arns" {
  type    = list(string)
  default = []
}

variable "storage_bucket_arns" {
  type    = list(string)
  default = []
}

variable "backup_bucket_arn" {
  type    = string
  default = ""
}

variable "ubuntu_version" {
  type    = string
  default = "24.04"
}
