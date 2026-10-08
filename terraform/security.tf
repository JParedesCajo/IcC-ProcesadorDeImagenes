
# Seguridad de Lambda: sin conexiones entrantes.

resource "aws_security_group" "upload_lambda" {
  name_prefix = "${var.project_name}-${var.environment}-upload-"
  description = "Seguridad de Lambda upload"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-sg-upload"
  }
}

resource "aws_security_group" "crop_lambda" {
  name_prefix = "${var.project_name}-${var.environment}-crop-"
  description = "Seguridad de Lambda crop"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-sg-crop"
  }
}

# Salida HTTPS para comunicarse con servicios AWS.
resource "aws_vpc_security_group_egress_rule" "upload_https" {
  security_group_id = aws_security_group.upload_lambda.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "crop_https" {
  security_group_id = aws_security_group.crop_lambda.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Seguridad del endpoint privado SQS.
resource "aws_security_group" "vpce_sqs" {
  name_prefix = "${var.project_name}-${var.environment}-sqs-"
  description = "Seguridad del endpoint SQS"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-sg-vpce-sqs"
  }
}

# Permitir HTTPS desde Lambda upload.
resource "aws_vpc_security_group_ingress_rule" "sqs_from_upload" {
  security_group_id            = aws_security_group.vpce_sqs.id
  referenced_security_group_id = aws_security_group.upload_lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

# Permitir HTTPS desde Lambda crop.
resource "aws_vpc_security_group_ingress_rule" "sqs_from_crop" {
  security_group_id            = aws_security_group.vpce_sqs.id
  referenced_security_group_id = aws_security_group.crop_lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
