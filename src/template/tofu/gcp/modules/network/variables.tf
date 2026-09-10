variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "secondary_ranges" {
  type    = map(string)
  default = {}
}

variable "enable_nat" {
  type    = bool
  default = false
}

variable "open_web" {
  type    = bool
  default = false
}

variable "open_ssh" {
  type    = bool
  default = false
}

variable "admin_cidrs" {
  type    = list(string)
  default = []

  validation {
    condition     = alltrue([for cidr in var.admin_cidrs : can(cidrhost(cidr, 0))])
    error_message = "ADMIN_CIDRS must be CIDRs — the networks allowed to reach the kubernetes api."
  }
}
