resource "aws_eks_addon" "pod_identity" {
  cluster_name = var.cluster_name
  addon_name   = "eks-pod-identity-agent"
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "storage" {
  for_each = var.storage

  statement {
    sid       = "Storage"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [each.value, "${each.value}/*"]
  }
}

data "aws_iam_policy_document" "backup" {
  statement {
    sid       = "Backups"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [var.backup_bucket_arn, "${var.backup_bucket_arn}/*"]
  }
}

resource "aws_iam_role" "storage" {
  for_each = var.storage

  name               = "${var.name}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "storage" {
  for_each = var.storage

  name   = "${var.name}-${each.key}"
  role   = aws_iam_role.storage[each.key].id
  policy = data.aws_iam_policy_document.storage[each.key].json
}

resource "aws_iam_role" "backup" {
  name               = "${var.name}-backup"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "backup" {
  name   = "${var.name}-backup"
  role   = aws_iam_role.backup.id
  policy = data.aws_iam_policy_document.backup.json
}

resource "aws_eks_pod_identity_association" "storage" {
  for_each = var.storage

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = each.key
  role_arn        = aws_iam_role.storage[each.key].arn

  depends_on = [aws_eks_addon.pod_identity]
}

resource "aws_eks_pod_identity_association" "backup" {
  for_each = toset(var.backup_accounts)

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = each.value
  role_arn        = aws_iam_role.backup.arn

  depends_on = [aws_eks_addon.pod_identity]
}
