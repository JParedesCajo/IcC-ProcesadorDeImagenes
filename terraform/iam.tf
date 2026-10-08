# Permite que AWS Lambda asuma estos roles.

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "upload" {
  name               = "${var.project_name}-${var.environment}-upload-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role" "crop" {
  name               = "${var.project_name}-${var.environment}-crop-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Permisos básicos: logs y conexiones dentro de la VPC.

resource "aws_iam_role_policy_attachment" "upload_vpc" {
  role       = aws_iam_role.upload.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "crop_vpc" {
  role       = aws_iam_role.crop.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Upload: solo puede escribir en uploads/.

resource "aws_iam_role_policy" "upload_s3" {
  name = "upload-s3"
  role = aws_iam_role.upload.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.images.arn}/uploads/*"
    }]
  })
}

# Crop: lee originales, guarda procesados y consume SQS.

resource "aws_iam_role_policy" "crop_access" {
  name = "crop-access"
  role = aws_iam_role.crop.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.images.arn}/uploads/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.images.arn}/processed/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.images.arn
      }
    ]
  })
}