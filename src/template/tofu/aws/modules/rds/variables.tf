variable "name" {
  type = string
}

variable "engine" {
  type = string
}

variable "engine_version" {
  type = string
}

variable "port" {
  type = number
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "allowed_cidr" {
  type    = string
  default = ""
}

variable "source_sg_id" {
  type    = string
  default = ""
}

variable "instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "disk_gb" {
  type    = number
  default = 50
}

variable "max_disk_gb" {
  type    = number
  default = 200
}

variable "username" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

variable "backup_days" {
  type    = number
  default = 7
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "replicas" {
  type    = number
  default = 0
}

variable "replica_instance_class" {
  type    = string
  default = ""
}

variable "apply_immediately" {
  type    = bool
  default = false
}
