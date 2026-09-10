locals {
  small = can(regex("\\.(micro|small)$", var.instance_class))
}

resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids

  tags = { Name = var.name }
}

resource "aws_security_group" "this" {
  name   = "${var.name}-rds"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.source_sg_id != "" ? [1] : []

    content {
      description     = var.engine
      from_port       = var.port
      to_port         = var.port
      protocol        = "tcp"
      security_groups = [var.source_sg_id]
    }
  }

  dynamic "ingress" {
    for_each = var.source_sg_id == "" ? [1] : []

    content {
      description = var.engine
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = [var.allowed_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-rds" }
}

resource "aws_db_instance" "this" {
  identifier = var.name

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.disk_gb
  max_allocated_storage = var.max_disk_gb
  storage_type          = "gp3"
  storage_encrypted     = true

  username = var.username
  password = var.password
  port     = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  multi_az               = var.multi_az
  publicly_accessible    = false

  backup_retention_period   = var.backup_days
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name}-final"
  apply_immediately         = var.apply_immediately

  performance_insights_enabled = !local.small

  tags = { Name = var.name }
}

resource "aws_db_instance" "replica" {
  count = var.replicas

  identifier          = "${var.name}-replica-${count.index + 1}"
  replicate_source_db = aws_db_instance.this.identifier
  instance_class      = var.replica_instance_class != "" ? var.replica_instance_class : var.instance_class

  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  apply_immediately      = var.apply_immediately

  performance_insights_enabled = !local.small

  tags = { Name = "${var.name}-replica-${count.index + 1}" }
}
