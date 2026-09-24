# modules/vpc/variables.tf

variable "vpc_cidr" {
  description = "CIDR block principal da VPC"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes e tag Project)"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "subnets" {
  description = "Mapa de subnets: chave = nome lógico (ex: public-1), valor = cidr, az e type"
  type = map(object({
    cidr = string
    az   = string
    type = string # "public" ou "private"
  }))

  validation {
    condition     = alltrue([for s in values(var.subnets) : contains(["public", "private"], s.type)])
    error_message = "O campo type de cada subnet deve ser \"public\" ou \"private\"."
  }
}
