variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "network" {
  type = string
}

variable "databases" {
  type = map(object({
    version = string
    user    = string
  }))
}

variable "passwords" {
  type      = map(string)
  sensitive = true
}

variable "tier" {
  type    = string
  default = "db-custom-1-3840"
}

variable "disk_gb" {
  type    = number
  default = 50
}

variable "backup_days" {
  type    = number
  default = 7
}

variable "multi_az" {
  type    = bool
  default = false
}
