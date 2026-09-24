# environments/staging/main.tf — ambiente STAGING

# ========================================
# Data Source: AMI Amazon Linux 2023
# ========================================
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ========================================
# Módulo VPC — subnets dinâmicas (for_each)
# ========================================
module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
  environment  = var.environment
  subnets      = var.subnets
}

# ========================================
# Security Group da API
# Composição: vpc_id ← módulo VPC
# ========================================
module "api_sg" {
  source = "../../modules/security-group"

  name         = "${var.project_name}-${var.environment}-api-sg"
  description  = "HTTP e SSH para a API"
  vpc_id       = module.vpc.vpc_id
  environment  = var.environment
  project_name = var.project_name

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP from anywhere"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
      description = "SSH"
    }
  ]
}

# ========================================
# Security Group do RDS
# Composição: vpc_id ← módulo VPC; origem ← SG da API
# ========================================
module "rds_sg" {
  source = "../../modules/security-group"

  name         = "${var.project_name}-${var.environment}-rds-sg"
  description  = "PostgreSQL apenas a partir do SG da API"
  vpc_id       = module.vpc.vpc_id
  environment  = var.environment
  project_name = var.project_name

  ingress_rules = [
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      source_security_group_id = module.api_sg.sg_id
      description              = "PostgreSQL from API SG"
    }
  ]
}

# ========================================
# Servidor da API (EC2)
# Composição: subnet_id ← VPC; security_group_ids ← SG da API
# ========================================
module "api_server" {
  source = "../../modules/ec2"

  instance_name      = "${var.project_name}-${var.environment}-api"
  instance_type      = var.instance_type
  ami_id             = data.aws_ami.amazon_linux.id
  subnet_id          = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.api_sg.sg_id]
  key_name           = var.key_name
  environment        = var.environment
  project_name       = var.project_name

  user_data = <<-EOT
    #!/bin/bash
    dnf install -y postgresql15
  EOT
}

# ========================================
# Banco de dados (RDS PostgreSQL)
# Composição: subnet_ids ← subnets privadas da VPC; security_group_ids ← SG do RDS
# ========================================
module "database" {
  source = "../../modules/rds"

  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.rds_sg.sg_id]
  instance_class     = var.db_instance_class
  environment        = var.environment
  project_name       = var.project_name
}
