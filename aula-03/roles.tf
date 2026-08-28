# =============================================
# Service Role — EC2 assume role para acessar S3
# =============================================

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

data "aws_iam_policy_document" "ec2_app_data" {
  statement {
    sid     = "AllowS3AppDataReadWrite"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::technova-app-data-*",
      "arn:aws:s3:::technova-app-data-*/*",
    ]
  }
}

resource "aws_iam_policy" "ec2_app_data" {
  name        = "${var.ra}-technova-ec2-app-data"
  description = "Leitura/escrita em buckets technova-app-data-* para instâncias EC2"
  policy      = data.aws_iam_policy_document.ec2_app_data.json
  tags        = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ec2_role_s3" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_app_data.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.ra}-technova-ec2-profile"
  role = aws_iam_role.ec2_role.name
  tags = local.common_tags
}
