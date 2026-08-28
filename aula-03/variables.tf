variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "TechNova"
}

variable "environment" {
  description = "Ambiente (development, staging, production)"
  type        = string
  default     = "development"
}

variable "aluno" {
  description = "Nome do aluno"
  type        = string
  default     = "Sirlande Martins"
}

variable "ra" {
  description = "RA do aluno (usado como prefixo dos recursos)"
  type        = string
  default     = "6325269"
}

locals {
  common_tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Aluno      = var.aluno
    RA         = var.ra
    Disciplina = "DevOps - UniFAAT 2026-2"
    Aula       = "03"
  }
}
