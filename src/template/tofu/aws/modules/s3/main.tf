resource "aws_s3_bucket" "this" {
  bucket = var.name

  tags = { Name = var.name }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = !var.public
  ignore_public_acls      = true
  restrict_public_buckets = !var.public
}

resource "aws_s3_bucket_policy" "public" {
  count = var.public ? 1 : 0

  bucket     = aws_s3_bucket.this.id
  depends_on = [aws_s3_bucket_public_access_block.this]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicMediaRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.this.arn}/*"
    }]
  })
}

resource "aws_s3_bucket_versioning" "this" {
  count = var.versioning ? 1 : 0

  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "hygiene"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = var.expire_days > 0 ? [1] : []

    content {
      id     = "expire"
      status = "Enabled"

      filter {}

      expiration {
        days = var.expire_days
      }

      noncurrent_version_expiration {
        noncurrent_days = var.expire_days
      }
    }
  }
}
