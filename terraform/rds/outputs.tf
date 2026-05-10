output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_endpoint" {
  description = "Connection endpoint (host:port) of the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "Hostname of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "Port the RDS instance listens on"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Default database name on the RDS instance"
  value       = aws_db_instance.main.db_name
}

output "db_master_username" {
  description = "Master username for the RDS instance"
  value       = aws_db_instance.main.username
  sensitive   = true
}


output "db_parameter_group_name" {
  description = "Name of the DB parameter group"
  value       = aws_db_parameter_group.mysql.name
}

# ─── Per-service secret ARNs (pass to EKS service accounts / IRSA) ───────────

output "secret_arns" {
  description = "Map of service name to Secrets Manager secret ARN"
  value = {
    for k, v in aws_secretsmanager_secret.db : k => v.arn
  }
}

output "customers_secret_arn" {
  description = "Secrets Manager ARN for the customers-service database credentials"
  value       = try(aws_secretsmanager_secret.db["customers"].arn, null)
}

output "visits_secret_arn" {
  description = "Secrets Manager ARN for the visits-service database credentials"
  value       = try(aws_secretsmanager_secret.db["visits"].arn, null)
}

output "vets_secret_arn" {
  description = "Secrets Manager ARN for the vets-service database credentials"
  value       = try(aws_secretsmanager_secret.db["vets"].arn, null)
}
