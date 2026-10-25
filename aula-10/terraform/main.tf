# ============================================================
# Infra de deploy da TechNova API (Aula 10)
# EC2 com Docker + AWS CLI, na VPC padrão do Learner Lab.
# Gerenciada só via GitOps: plan no PR, apply no merge.
# ============================================================

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Ubuntu 24.04 LTS (Canonical) — usuário SSH "ubuntu".
# Parâmetro público do SSM mantido pela Canonical: no Learner Lab a busca
# de AMIs por owner (data "aws_ami") não retorna resultados.
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# ---------- Security Group ----------
resource "aws_security_group" "technova_api" {
  name        = "${var.project_name}-api-sg"
  description = "TechNova API - teste do guard de destroy (nao mergear)"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${var.project_name}-api-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.ssh_cidr_blocks)

  security_group_id = aws_security_group.technova_api.id
  description       = "SSH para os runners do GitHub Actions (deploy)"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  for_each = toset(var.app_cidr_blocks)

  security_group_id = aws_security_group.technova_api.id
  description       = "TechNova API (health check e acesso externo)"
  ip_protocol       = "tcp"
  from_port         = var.app_port
  to_port           = var.app_port
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.technova_api.id
  description       = "Saida liberada (pull no ECR, pacotes)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------- Chave SSH do pipeline ----------
resource "aws_key_pair" "deploy" {
  key_name   = "${var.project_name}-deploy"
  public_key = file("${path.module}/${var.ssh_public_key_path}")
}

# ---------- EC2 ----------
resource "aws_instance" "api" {
  ami                         = nonsensitive(data.aws_ssm_parameter.ubuntu_ami.value)
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.technova_api.id]
  key_name                    = aws_key_pair.deploy.key_name
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    aws_region = var.aws_region
  })

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-api"
    Role = "technova-api-deploy" # usada pelo cd.yml para achar o host
  }

  lifecycle {
    # Nova AMI publicada ou ajuste no user_data não devem recriar a EC2
    # (o destroy derrubaria a aplicação em produção)
    ignore_changes = [ami, user_data]
  }
}
