variable "name" {
  type = string
}

variable "k8s_version" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "node_type" {
  type    = string
  default = "t3.medium"
}

variable "node_disk_gb" {
  type    = number
  default = 30
}

variable "node_max_pods" {
  type    = number
  default = 110
}

variable "node_min" {
  type    = number
  default = 2
}

variable "node_desired" {
  type    = number
  default = 2
}

variable "node_max" {
  type    = number
  default = 4
}
