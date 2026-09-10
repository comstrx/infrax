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

variable "subnet_id" {
  type = string
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "disk_gb" {
  type    = number
  default = 40
}

variable "image" {
  type    = string
  default = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "ssh_user" {
  type = string
}

variable "ssh_public_key" {
  type    = string
  default = ""
}

variable "repository" {
  type = string
}

variable "buckets" {
  type    = list(string)
  default = []
}

variable "backup_bucket" {
  type = string
}
