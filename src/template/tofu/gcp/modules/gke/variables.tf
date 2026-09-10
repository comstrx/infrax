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

variable "network" {
  type = string
}

variable "subnet" {
  type = string
}

variable "admin_cidrs" {
  type    = list(string)
  default = []
}

variable "master_cidr" {
  type    = string
  default = "172.16.0.0/28"
}

variable "node_type" {
  type    = string
  default = "e2-standard-4"
}

variable "node_disk_gb" {
  type    = number
  default = 30
}

variable "node_min" {
  type    = number
  default = 1
}

variable "node_max" {
  type    = number
  default = 5
}
