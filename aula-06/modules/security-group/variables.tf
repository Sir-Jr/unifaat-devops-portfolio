# modules/security-group/variables.tf

variable "name" {
  description = "Nome do Security Group"
  type        = string
}

variable "description" {
  description = "Descrição do Security Group"
  type        = string
  default     = "Managed by Terraform"
}

variable "vpc_id" {
  description = "ID da VPC onde o SG será criado"
  type        = string
}

variable "ingress_rules" {
  description = <<-EOT
    Lista de regras de entrada. Cada regra libera a origem por cidr_blocks OU por
    source_security_group_id (outro SG) — informe apenas um dos dois.
  EOT
  type = list(object({
    from_port                = number
    to_port                  = number
    protocol                 = string
    description              = string
    cidr_blocks              = optional(list(string), [])
    source_security_group_id = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for r in var.ingress_rules :
      (length(r.cidr_blocks) > 0) != (r.source_security_group_id != null)
    ])
    error_message = "Cada regra de ingress deve ter cidr_blocks OU source_security_group_id (exatamente um)."
  }
}

variable "egress_rules" {
  description = "Lista de regras de saída (padrão: todo tráfego liberado)"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound"
    }
  ]
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto para tags"
  type        = string
}
