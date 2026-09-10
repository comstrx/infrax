resource "aws_cloudwatch_log_group" "this" {
  for_each = toset(var.log_groups)

  name              = each.value
  retention_in_days = var.retention_days
}

resource "aws_sns_topic" "this" {
  count = var.alarm_email != "" ? 1 : 0

  name = "${var.name}-alarms"
}

resource "aws_sns_topic_subscription" "this" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.this[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = var.alarms

  alarm_name          = "${var.name}-${each.key}"
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  dimensions          = each.value.dimensions
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = each.value.threshold
  comparison_operator = each.value.operator
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.this[0].arn] : []
  ok_actions    = var.alarm_email != "" ? [aws_sns_topic.this[0].arn] : []
}
