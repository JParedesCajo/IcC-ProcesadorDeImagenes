
# NAT Gateway para las dos zonas de disponibilidad.
# Solo se crean cuando enable_nat es true.

resource "aws_eip" "nat_a" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip-a"
  }
}

resource "aws_eip" "nat_b" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip-b"
  }
}

resource "aws_nat_gateway" "nat_a" {
  count = var.enable_nat ? 1 : 0

  allocation_id = aws_eip.nat_a[0].id
  subnet_id     = aws_subnet.public_a.id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-a"
  }
}

resource "aws_nat_gateway" "nat_b" {
  count = var.enable_nat ? 1 : 0

  allocation_id = aws_eip.nat_b[0].id
  subnet_id     = aws_subnet.public_b.id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-b"
  }
}

# Cada subred privada utiliza su NAT correspondiente.

resource "aws_route" "private_a_internet" {
  count = var.enable_nat ? 1 : 0

  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a[0].id
}

resource "aws_route" "private_b_internet" {
  count = var.enable_nat ? 1 : 0

  route_table_id         = aws_route_table.private_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_b[0].id
}
