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

locals {
  common_tags = {
    Project = "TechNova"
    Purpose = "Terraform Remote State"
  }
}
