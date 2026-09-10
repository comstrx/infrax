variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "repository" {
  type = string
}

variable "keep_images" {
  type    = number
  default = 20
}
