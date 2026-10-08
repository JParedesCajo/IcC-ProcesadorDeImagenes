
# Endpoint S3 Gateway.
# Permite acceder a S3 desde las subredes privadas.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_a.id,
    aws_route_table.private_b.id
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-vpce-s3"
  }
}

# Endpoint SQS Interface.
# Una interfaz de red privada en cada zona.

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  count               = var.enable_sqs_endpoint ? 1 : 0

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  security_group_ids = [
    aws_security_group.vpce_sqs.id
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-vpce-sqs"
  }
}
