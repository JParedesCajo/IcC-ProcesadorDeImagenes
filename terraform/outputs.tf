output "api_url" {
  description = "URL para solicitar la subida de imágenes"
  value       = "${aws_apigatewayv2_api.images.api_endpoint}/upload"
}

output "s3_bucket_name" {
  description = "Nombre del bucket de imágenes"
  value       = aws_s3_bucket.images.id
}

output "sqs_queue_url" {
  description = "URL de la cola principal"
  value       = aws_sqs_queue.images.url
}

output "sns_topic_arn" {
  description = "ARN del tema de alertas"
  value       = aws_sns_topic.alerts.arn
}