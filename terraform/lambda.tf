
# Empaquetar los archivos JavaScript en ZIP.

data "archive_file" "upload" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/upload"
  output_path = "${path.module}/upload.zip"
}

data "archive_file" "crop" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/crop"
  output_path = "${path.module}/crop.zip"
}

# Registros de ejecución durante 14 días.

resource "aws_cloudwatch_log_group" "upload" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-upload"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "crop" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-crop"
  retention_in_days = 14
}

# Lambda para generar la URL de subida.

resource "aws_lambda_function" "upload" {
  function_name = "${var.project_name}-${var.environment}-upload"
  role          = aws_iam_role.upload.arn
  runtime       = "nodejs22.x"
  architectures = ["x86_64"]
  handler       = "index.handler"

  filename         = data.archive_file.upload.output_path
  source_code_hash = data.archive_file.upload.output_base64sha256

  memory_size = 256
  timeout     = 30

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_group_ids = [
      aws_security_group.upload_lambda.id
    ]
  }

  environment {
    variables = {
      S3_BUCKET     = aws_s3_bucket.images.id
      UPLOAD_PREFIX = "uploads/"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.upload_vpc,
    aws_iam_role_policy.upload_s3,
    aws_cloudwatch_log_group.upload
  ]
}

# Lambda para procesar imágenes.

resource "aws_lambda_function" "crop" {
  function_name = "${var.project_name}-${var.environment}-crop"
  role          = aws_iam_role.crop.arn
  runtime       = "nodejs22.x"
  architectures = ["x86_64"]
  handler       = "index.handler"

  filename         = data.archive_file.crop.output_path
  source_code_hash = data.archive_file.crop.output_base64sha256

  memory_size = 512
  timeout     = 60

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_group_ids = [
      aws_security_group.crop_lambda.id
    ]
  }

  environment {
    variables = {
      S3_BUCKET        = aws_s3_bucket.images.id
      PROCESSED_PREFIX = "processed/"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.crop_vpc,
    aws_iam_role_policy.crop_access,
    aws_cloudwatch_log_group.crop
  ]
}

# SQS activa automáticamente Lambda Crop.

resource "aws_lambda_event_source_mapping" "images" {
  event_source_arn        = aws_sqs_queue.images.arn
  function_name           = aws_lambda_function.crop.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]

  depends_on = [aws_iam_role_policy.crop_access]
}
