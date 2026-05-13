output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private app subnets"
  value       = aws_subnet.private[*].id
}

output "db_subnet_ids" {
  description = "IDs of the database subnets"
  value       = aws_subnet.database[*].id
}

output "db_subnet_group_name" {
  description = "Name of the RDS DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

# ─── Security Group IDs (consumed by other modules) ──────────────────────────

output "sg_app_services_id" {
  description = "Security group ID for the business microservices"
  value       = aws_security_group.app_services.id
}

output "sg_infra_services_id" {
  description = "Security group ID for Config Server and Eureka"
  value       = aws_security_group.infra_services.id
}

output "sg_monitoring_id" {
  description = "Security group ID for the monitoring stack"
  value       = aws_security_group.monitoring.id
}

output "sg_database_id" {
  description = "Security group ID for the MySQL database"
  value       = aws_security_group.database.id
}
