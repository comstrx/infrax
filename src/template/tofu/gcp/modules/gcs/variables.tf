variable "region" {
  type = string
}

variable "buckets" {
  type = map(object({
    service = string
    account = string
    public  = bool
  }))

  default = {}
}
