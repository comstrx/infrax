variable "name" {
  type = string
}

variable "cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "enable_nat" {
  type    = bool
  default = true
}

variable "cluster_name" {
  type    = string
  default = ""
}
