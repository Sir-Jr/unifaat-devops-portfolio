# =============================================
# Custom Policies (menor privilégio) + Attachments
# =============================================

# --- Developers: leitura em buckets technova-* ---
data "aws_iam_policy_document" "s3_read" {
  statement {
    sid     = "AllowS3Read"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::technova-*",
      "arn:aws:s3:::technova-*/*",
    ]
  }
}

resource "aws_iam_policy" "s3_read" {
  name        = "${var.ra}-technova-s3-read"
  description = "Leitura de objetos em buckets technova-*"
  policy      = data.aws_iam_policy_document.s3_read.json
  tags        = local.common_tags
}

# --- Platform Engineering: EC2 (describe + start/stop com condition) + S3 read/write ---
data "aws_iam_policy_document" "ec2_s3_full" {
  statement {
    sid       = "AllowEC2Describe"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances", "ec2:DescribeInstanceStatus"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowEC2LifecycleTaggedOnly"
    effect    = "Allow"
    actions   = ["ec2:StartInstances", "ec2:StopInstances"]
    resources = ["arn:aws:ec2:*:*:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Project"
      values   = ["TechNova"]
    }
  }

  statement {
    sid    = "AllowS3ReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::technova-*",
      "arn:aws:s3:::technova-*/*",
    ]
  }
}

resource "aws_iam_policy" "ec2_s3_full" {
  name        = "${var.ra}-technova-ec2-s3-full"
  description = "EC2 describe + start/stop (tag Project=TechNova) e S3 read/write em technova-*"
  policy      = data.aws_iam_policy_document.ec2_s3_full.json
  tags        = local.common_tags
}

# --- Deny explícito para ações destrutivas (proteção extra dos developers) ---
data "aws_iam_policy_document" "deny_destructive" {
  statement {
    sid       = "DenyDestructiveActions"
    effect    = "Deny"
    actions   = ["s3:Delete*", "ec2:Terminate*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deny_destructive" {
  name        = "${var.ra}-technova-deny-destructive"
  description = "Deny explícito para ações destrutivas (S3 Delete*, EC2 Terminate*)"
  policy      = data.aws_iam_policy_document.deny_destructive.json
  tags        = local.common_tags
}

# --- Attachments ---
resource "aws_iam_group_policy_attachment" "developers_s3_read" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.s3_read.arn
}

resource "aws_iam_group_policy_attachment" "developers_deny_destructive" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.deny_destructive.arn
}

resource "aws_iam_group_policy_attachment" "platform_eng_ec2_s3_full" {
  group      = aws_iam_group.platform_eng.name
  policy_arn = aws_iam_policy.ec2_s3_full.arn
}
