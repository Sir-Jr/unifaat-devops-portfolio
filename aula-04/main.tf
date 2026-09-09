# =============================================================
# VPC
# =============================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "technova-vpc"
  })
}

# =============================================================
# SUBNETS — 2 públicas + 2 privadas, distribuídas em 2 AZs
# =============================================================

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "technova-public-subnet-${count.index + 1}"
    Type = "public"
  })
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "technova-private-subnet-${count.index + 1}"
    Type = "private"
  })
}

# =============================================================
# INTERNET GATEWAY + ROUTE TABLE PÚBLICA
# =============================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "technova-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "technova-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Subnets privadas usam a Route Table padrão da VPC (sem rota para o IGW).

# =============================================================
# SECURITY GROUPS
# =============================================================

resource "aws_security_group" "api" {
  name        = "technova-api-sg"
  description = "Permite SSH e API Node.js na instancia publica"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "API Node.js"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "technova-api-sg"
  })
}

resource "aws_security_group" "db" {
  name        = "technova-db-sg"
  description = "Permite PostgreSQL apenas de dentro da VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "technova-db-sg"
  })
}

# =============================================================
# AMI — Amazon Linux 2023 via data source
# =============================================================

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

# =============================================================
# KEY PAIR
# =============================================================

resource "aws_key_pair" "main" {
  key_name   = "technova-key"
  public_key = file(var.public_key_path)

  tags = merge(local.common_tags, {
    Name = "technova-key"
  })
}

# =============================================================
# IAM ROLE + INSTANCE PROFILE — S3 ReadOnly para a EC2
# =============================================================

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.ra}-technova-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ec2_s3_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.ra}-technova-ec2-profile"
  role = aws_iam_role.ec2_role.name
  tags = local.common_tags
}

# A role voclabs do AWS Academy Learner Lab tem Deny explícito para iam:CreateRole,
# então os 3 recursos acima nunca aplicam neste ambiente (ver README). Para a EC2
# ficar funcional mesmo assim, usamos o LabInstanceProfile pré-provisionado pela
# AWS Academy (role LabRole já aceita ec2.amazonaws.com como principal).
data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

# =============================================================
# EC2 — API TechNova na subnet pública
# =============================================================

resource "aws_instance" "api" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.api.id]
  key_name               = aws_key_pair.main.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.lab.name
  user_data              = file("${path.module}/user_data.sh")

  tags = merge(local.common_tags, {
    Name = "technova-api-ec2"
  })
}
