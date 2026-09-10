output "topic_arn" {
  value = var.alarm_email != "" ? aws_sns_topic.this[0].arn : ""
}
