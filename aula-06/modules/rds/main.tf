# modules/rds/main.tf

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ========================================
# DB Subnet Group — subnets privadas em 2+ AZs
# ========================================
resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

# ========================================
# Instância RDS PostgreSQL
# ========================================
resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-db"

  engine         = "postgres"
  engine_version = var.engine_version

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false
  multi_az               = false

  # Configurações para ambientes de desenvolvimento/testes
  skip_final_snapshot          = true
  deletion_protection          = false
  backup_retention_period      = 0
  performance_insights_enabled = false
  apply_immediately            = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db"
  })
}
