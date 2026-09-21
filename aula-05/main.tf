# Definições compartilhadas: tags comuns e data sources usados por vpc.tf, rds.tf e ec2.tf.
# O backend remoto (S3 + DynamoDB) fica em providers.tf.

locals {
  common_tags = {
    Project = "TechNova"
    Aula    = "05"
    Owner   = var.ra
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
