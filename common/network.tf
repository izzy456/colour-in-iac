# Network

# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# DHCP Options
resource "aws_vpc_dhcp_options" "dhcp_options" {
  domain_name         = var.region == "us-east-1" ? "ec2.internal" : "${var.region}.compute.internal"
  domain_name_servers = ["AmazonProvidedDNS"]
}

# IGW
resource "aws_internet_gateway" "internet_gateway" {
  depends_on = [aws_vpc.vpc]
}

resource "aws_internet_gateway_attachment" "internet_gateway_attachment" {
  depends_on          = [aws_internet_gateway.internet_gateway]
  internet_gateway_id = aws_internet_gateway.internet_gateway.id
  vpc_id              = aws_vpc.vpc.id
}

### Public ###

# Public Route Table
resource "aws_route_table" "public_route_table" {
  depends_on = [aws_vpc.vpc]
  vpc_id     = aws_vpc.vpc.id
}

# Public Route (through IGW)
resource "aws_route" "public_route" {
  depends_on             = [aws_route_table.public_route_table, aws_internet_gateway_attachment.internet_gateway_attachment]
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

data "aws_availability_zones" "azs" {
  state = "available"
}

# Public Subnets
resource "aws_subnet" "public_subnet" {
  depends_on        = [aws_route_table.public_route_table]
  count             = min(length(data.aws_availability_zones.azs.names), 3)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.azs.names[count.index]
}

resource "aws_route_table_association" "public_subnet_rt_assoc" {
  depends_on     = [aws_subnet.public_subnet]
  count          = length(aws_subnet.public_subnet.*.id)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public_route_table.id
}

### Private ###

# Private Route Table
resource "aws_route_table" "private_route_table" {
  depends_on = [aws_vpc.vpc]
  vpc_id     = aws_vpc.vpc.id
}

# SG for VPC Endpoints
resource "aws_security_group" "vpc_endpoints_sg" {
  depends_on  = [aws_security_group.service_sg_frontend, aws_security_group.service_sg_backend]
  name        = "${var.project_name}-vpc-endpoints-sg"
  description = "VPC endpoints SG"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Allow HTTPS to VPC endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.service_sg_frontend.id, aws_security_group.service_sg_backend.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# VPC Endpoint for ECR API
resource "aws_vpc_endpoint" "ecr_api_vpc_endpoint" {
  depends_on          = [aws_subnet.private_subnet, aws_subnet.private_subnet]
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private_subnet.*.id
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
}

# VPC Endpoint for ECR docker registry API
resource "aws_vpc_endpoint" "ecr_dkr_vpc_endpoint" {
  depends_on          = [aws_subnet.private_subnet]
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private_subnet.*.id
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
}

# VPC Endpoint for ECR S3
resource "aws_vpc_endpoint" "ecr_s3_vpc_endpoint" {
  depends_on        = [aws_route_table.private_route_table]
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_route_table.id]
}

# VPC Endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "ecr_cloudwatch_vpc_endpoint" {
  depends_on          = [aws_subnet.private_subnet]
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private_subnet.*.id
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
}

# Private Subnets
resource "aws_subnet" "private_subnet" {
  depends_on        = [aws_route_table.private_route_table, aws_subnet.public_subnet]
  count             = min(length(data.aws_availability_zones.azs.names), 3)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.${length(aws_subnet.public_subnet.*.id) + count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.azs.names[count.index]
}

resource "aws_route_table_association" "private_subnet_rt_assoc" {
  depends_on     = [aws_subnet.private_subnet]
  count          = length(aws_subnet.private_subnet.*.id)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private_route_table.id
}