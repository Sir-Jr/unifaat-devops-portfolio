variable "aws_region" {
  description = "Região AWS para criar os recursos"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto (usado em tags e nomes de recursos)"
  type        = string
  default     = "technova"
}

variable "ra" {
  description = "RA do aluno (usado na tag Owner)"
  type        = string
  default     = "6325269"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR da subnet pública (EC2)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas em 2 AZs diferentes (DB Subnet Group)"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.4.0/24"]
}

variable "instance_type" {
  description = "Tipo da instância EC2 (Free Tier)"
  type        = string
  default     = "t2.micro"
}

variable "public_key_path" {
  description = "Caminho local da chave pública SSH registrada na AWS"
  type        = string
  default     = "~/.ssh/technova-key.pub"
}

variable "db_name" {
  description = "Nome do banco de dados criado no RDS"
  type        = string
  default     = "technova"
}

variable "db_username" {
  description = "Username administrativo do RDS"
  type        = string
  default     = "technova_admin"
}

variable "db_password" {
  description = "Senha do RDS (fornecida via terraform.tfvars, nunca versionado)"
  type        = string
  sensitive   = true
}
