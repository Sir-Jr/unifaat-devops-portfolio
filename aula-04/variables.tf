variable "aws_region" {
  description = "Região AWS para criar os recursos"
  type        = string
  default     = "us-east-1"
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

variable "availability_zones" {
  description = "AZs usadas para distribuir as subnets (uma pública + uma privada por AZ)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas, uma por AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas, uma por AZ"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.4.0/24"]
}

variable "instance_type" {
  description = "Tipo da instância EC2 (mantido em Free Tier)"
  type        = string
  default     = "t2.micro"
}

variable "public_key_path" {
  description = "Caminho local da chave pública SSH registrada na AWS"
  type        = string
  default     = "~/.ssh/technova-key.pub"
}

locals {
  common_tags = {
    Project     = "TechNova"
    Environment = "development"
    ManagedBy   = "Terraform"
    Owner       = var.ra
  }
}
