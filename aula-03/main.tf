# =============================================
# TF Aula 03: IAM completo — TechNova
# Groups, Users, Memberships
# =============================================

resource "aws_iam_group" "developers" {
  name = "${var.ra}-technova-developers"
}

resource "aws_iam_group" "platform_eng" {
  name = "${var.ra}-technova-platform-eng"
}

resource "aws_iam_user" "juliana" {
  name = "${var.ra}-juliana-dev"
  tags = local.common_tags
}

resource "aws_iam_user" "rafael" {
  name = "${var.ra}-rafael-platform"
  tags = local.common_tags
}

resource "aws_iam_user" "lucas" {
  name = "${var.ra}-lucas-intern"
  tags = local.common_tags
}

# Juliana: developers
resource "aws_iam_group_membership" "developers" {
  name  = "${var.ra}-developers-membership"
  group = aws_iam_group.developers.name

  users = [
    aws_iam_user.juliana.name,
    aws_iam_user.rafael.name,
    aws_iam_user.lucas.name,
  ]
}

# Rafael: developers + platform-eng
resource "aws_iam_group_membership" "platform_eng" {
  name  = "${var.ra}-platform-eng-membership"
  group = aws_iam_group.platform_eng.name

  users = [
    aws_iam_user.rafael.name,
  ]
}
