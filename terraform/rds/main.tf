locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ─── MASTER PASSWORD ─────────────────────────────────────────────────────────

resource "random_password" "master" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ─── PARAMETER GROUP ─────────────────────────────────────────────────────────

resource "aws_db_parameter_group" "mysql" {
  name        = "${local.name_prefix}-mysql84"
  family      = "mysql8.4"
  description = "MySQL 8.4 parameters tuned for Spring Boot / JPA"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = "200"
  }

  # Allow Spring Boot's schema validation to read table metadata
  parameter {
    name  = "innodb_stats_on_metadata"
    value = "0"
  }

  # Reduce lock wait timeout to surface deadlocks faster in dev
  parameter {
    name  = "innodb_lock_wait_timeout"
    value = "30"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = {
    Name = "${local.name_prefix}-mysql84-params"
  }
}

# ─── RDS INSTANCE ────────────────────────────────────────────────────────────

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-mysql"

  engine         = "mysql"
  engine_version = var.mysql_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true

  db_name  = "petclinic"
  username = var.master_username
  password = random_password.master.result

  db_subnet_group_name   = var.db_subnet_group_name
  parameter_group_name   = aws_db_parameter_group.mysql.name
  vpc_security_group_ids = [var.sg_database_id]

  multi_az               = var.multi_az
  publicly_accessible    = false
  deletion_protection    = var.deletion_protection
  skip_final_snapshot    = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name_prefix}-final-snapshot"

  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  performance_insights_enabled = false

  enabled_cloudwatch_logs_exports = ["general", "error", "slowquery"]

  tags = {
    Name = "${local.name_prefix}-mysql"
  }

}

# ─── PER-SERVICE SECRETS (one per microservice database) ─────────────────────
# Each service gets its own IAM-accessible secret with connection details.
# Microservices read these at startup via Spring Cloud AWS or init containers.

resource "aws_secretsmanager_secret" "db" {
  for_each = var.databases

  name                    = "${local.name_prefix}/rds/${each.key}"
  description             = "RDS credentials for the ${each.key} service"
  recovery_window_in_days = 0

  tags = {
    Name    = "${local.name_prefix}-rds-secret-${each.key}"
    Service = each.key
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  for_each = var.databases

  secret_id = aws_secretsmanager_secret.db[each.key].id

  secret_string = jsonencode({
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = each.value
    username = var.master_username
    password = random_password.master.result
    url      = "jdbc:mysql://${aws_db_instance.main.address}:${aws_db_instance.main.port}/${each.value}?useSSL=true&requireSSL=true"
  })
}
