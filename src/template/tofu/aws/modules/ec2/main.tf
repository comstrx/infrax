data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/${var.ubuntu_version}/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_security_group" "this" {
  name   = var.name
  vpc_id = var.vpc_id

  ingress {
    description = "ssh (key-only, the release line reaches it from anywhere)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.admin_cidrs

    content {
      description = "kubernetes api"
      from_port   = 6443
      to_port     = 6443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = var.name }
}

resource "aws_key_pair" "this" {
  count = var.ssh_public_key != "" ? 1 : 0

  key_name   = var.name
  public_key = var.ssh_public_key
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "node" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPull"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]

    resources = length(var.ecr_arns) > 0 ? var.ecr_arns : ["*"]
  }

  dynamic "statement" {
    for_each = length(var.storage_bucket_arns) > 0 ? [1] : []

    content {
      sid       = "Storage"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      resources = concat(var.storage_bucket_arns, [for arn in var.storage_bucket_arns : "${arn}/*"])
    }
  }

  dynamic "statement" {
    for_each = var.backup_bucket_arn != "" ? [1] : []

    content {
      sid       = "Backups"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      resources = [var.backup_bucket_arn, "${var.backup_bucket_arn}/*"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-node"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "node" {
  name   = "${var.name}-node"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.node.json
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name}-node"
  role = aws_iam_role.node.name
}

resource "aws_instance" "this" {
  ami                    = data.aws_ssm_parameter.ubuntu.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = aws_iam_instance_profile.node.name
  key_name               = var.ssh_public_key != "" ? aws_key_pair.this[0].key_name : null

  root_block_device {
    volume_size = var.disk_gb
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  lifecycle {
    ignore_changes = [ami]

    precondition {
      condition     = var.ssh_public_key != ""
      error_message = "SSH_PUBLIC_KEY is required — a keyless box has no management path."
    }
  }

  tags = { Name = var.name }
}

resource "aws_eip" "this" {
  instance = aws_instance.this.id
  domain   = "vpc"

  tags = { Name = var.name }
}
