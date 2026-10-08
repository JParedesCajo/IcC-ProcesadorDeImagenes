
# SNS: notificaciones cuando haya errores de procesamiento.

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = {
    Environment = var.environment
  }
}

# CloudWatch: detectar mensajes en la cola de errores.

resource "aws_cloudwatch_metric_alarm" "dlq" {
  alarm_name        = "${var.project_name}-${var.environment}-dlq-alarm"
  alarm_description = "Alerta cuando existen mensajes en la DLQ"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  treat_missing_data = "notBreaching"
}

# Suscripción opcional por correo

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "var.alert_email"
}