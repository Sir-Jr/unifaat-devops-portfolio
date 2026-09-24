# modules/rds/variables.tf

variable "db_name" {
  description = "Nome do database inicial"
  type        = string
}

variable "db_username" {
  description = "Usuário master do banco"
  type        = string
}

variable "db_password" {
  description = "Senha do usuário master (use apenas caracteres alfanuméricos)"
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "Subnet IDs (privadas, em 2+ AZs) para o DB Subnet Group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Lista de Security Group IDs associados ao RDS"
  type        = list(string)
}

variable "instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "engine_version" {
  description = "Versão major do PostgreSQL"
  type        = string
  default     = "15"
}

variable "allocated_storage" {
  description = "Armazenamento em GB"
  type        = number
  default     = 20
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes e tag Project)"
  type        = string
}
