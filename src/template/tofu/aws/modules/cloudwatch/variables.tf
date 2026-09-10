variable "name" {
  type = string
}

variable "log_groups" {
  type    = list(string)
  default = []
}

variable "retention_days" {
  type    = number
  default = 30
}

variable "alarm_email" {
  type    = string
  default = ""
}

variable "alarms" {
  type = map(object({
    namespace  = string
    metric     = string
    threshold  = number
    dimensions = map(string)
    operator   = optional(string, "GreaterThanThreshold")
  }))

  default = {}
}
