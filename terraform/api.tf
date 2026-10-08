# API Gateway HTTP API

resource "aws_apigatewayv2_api" "images" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }

  tags = {
    Environment = var.environment
  }
}

# Conectar API Gateway con Lambda Upload

resource "aws_apigatewayv2_integration" "upload" {
  api_id                 = aws_apigatewayv2_api.images.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.upload.invoke_arn
  payload_format_version = "2.0"
}

# Endpoint POST /upload

resource "aws_apigatewayv2_route" "upload" {
  api_id    = aws_apigatewayv2_api.images.id
  route_key = "POST /upload"

  target = "integrations/${aws_apigatewayv2_integration.upload.id}"
}

# Permitir que API Gateway invoque Lambda Upload

resource "aws_lambda_permission" "api_upload" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.images.execution_arn}/*/POST/upload"
}

# Grupo de logs de API Gateway

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = 14
}

# Etapa predeterminada con despliege automático

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.images.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn

    format = jsonencode({
      requestId        = "$context.requestId"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLength   = "$context.respondeseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }
}