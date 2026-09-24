# environments/dev/variables.tf

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto (prefixo dos recursos)"
  type        = string
}

variable "environment" {
  description = "Nome do ambiente"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
}

variable "subnets" {
  description = "Mapa de subnets da VPC (nome → cidr, az, type)"
  type = map(object({
    cidr = string
    az   = string
    type = string
  }))
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs com acesso SSH à EC2 da API"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_type" {
  description = "Tipo da instância EC2 da API"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Key pair existente na conta (no Learner Lab: vockey)"
  type        = string
  default     = "vockey"
}

variable "db_instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Nome do database PostgreSQL"
  type        = string
}

variable "db_username" {
  description = "Usuário master do PostgreSQL"
  type        = string
  default     = "technova_admin"
}

variable "db_password" {
  description = "Senha master do PostgreSQL — informe via TF_VAR_db_password, nunca no .tfvars"
  type        = string
  sensitive   = true
}
