variable "aws_region" {
  description = "Região da AWS (o Learner Lab trabalha em us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo dos nomes dos recursos"
  type        = string
  default     = "technova-aula10"
}

variable "instance_type" {
  description = "Tipo da EC2 que recebe os deploys"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Porta da TechNova API no container"
  type        = number
  default     = 3000
}

variable "ssh_cidr_blocks" {
  description = "Origem liberada para SSH. Os runners do GitHub Actions não têm IP fixo, então no Lab fica aberto; em produção, restringir aos ranges de https://api.github.com/meta"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_cidr_blocks" {
  description = "Origem liberada para a API (health check do pipeline e acesso externo)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_public_key_path" {
  description = "Chave pública usada pelo pipeline de CD (a privada fica só no secret EC2_SSH_KEY)"
  type        = string
  default     = "technova-deploy.pub"
}

variable "instance_profile_name" {
  description = "Instance profile já existente no Learner Lab (dá à EC2 permissão de pull no ECR sem criar IAM)"
  type        = string
  default     = "LabInstanceProfile"
}
