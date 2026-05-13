locals {
  sg_prefix = "${var.project_name}-${var.environment}"
}

# ─── BUSINESS SERVICES ───────────────────────────────────────────────────────
# Customers (8081), Visits (8082), Vets (8083), GenAI (8084)
# Accept traffic from the API Gateway only

resource "aws_security_group" "app_services" {
  name        = "${local.sg_prefix}-app-services-sg"
  description = "Allow ports 8081-8084 from API Gateway"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Microservice ports from API Gateway"
    from_port       = 8081
    to_port         = 8084
    protocol        = "tcp"
    security_groups = [aws_security_group.api_gateway.id]
  }

  # Allow inter-service communication (e.g., GenAI calling other services)
  ingress {
    description = "Inter-service communication"
    from_port   = 8081
    to_port     = 8084
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.sg_prefix}-app-services-sg"
  }
}

# ─── INFRASTRUCTURE SERVICES ─────────────────────────────────────────────────
# Config Server (8888) and Discovery Server / Eureka (8761)
# Accessible only by app services and the API Gateway

resource "aws_security_group" "infra_services" {
  name        = "${local.sg_prefix}-infra-services-sg"
  description = "Config Server and Eureka Discovery - internal access only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Config Server from app services"
    from_port       = 8888
    to_port         = 8888
    protocol        = "tcp"
    security_groups = [aws_security_group.app_services.id, aws_security_group.api_gateway.id]
  }

  ingress {
    description     = "Eureka from app services"
    from_port       = 8761
    to_port         = 8761
    protocol        = "tcp"
    security_groups = [aws_security_group.app_services.id, aws_security_group.api_gateway.id]
  }

  # Config and Discovery need to reach each other
  ingress {
    description = "Intra-infra communication"
    from_port   = 8761
    to_port     = 8888
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.sg_prefix}-infra-services-sg"
  }
}

# ─── MONITORING STACK ────────────────────────────────────────────────────────
# Admin Server (9090), Prometheus (9091), Zipkin (9411), Grafana (3030)
# Accessible only from within the VPC

resource "aws_security_group" "monitoring" {
  name        = "${local.sg_prefix}-monitoring-sg"
  description = "Monitoring stack - VPC-internal access only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Spring Boot Admin"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9091
    to_port     = 9091
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Zipkin"
    from_port   = 9411
    to_port     = 9411
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Grafana"
    from_port   = 3030
    to_port     = 3030
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.sg_prefix}-monitoring-sg"
  }
}

# ─── DATABASE ────────────────────────────────────────────────────────────────
# MySQL (3306) — accessible only from app services

resource "aws_security_group" "database" {
  name        = "${local.sg_prefix}-database-sg"
  description = "MySQL - allow port 3306 from app services only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from app services"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_services.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.sg_prefix}-database-sg"
  }
}
