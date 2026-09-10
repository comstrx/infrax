locals {
  backup_bucket_arn = "arn:aws:s3:::${var.backup_bucket}"
}

resource "aws_eip" "edge" {
  count = var.edge_fixed_ips ? var.az_count : 0

  domain = "vpc"

  tags = { Name = "${var.name}-edge-${count.index}" }
}

module "network" {
  source = "../../modules/network"

  name         = var.name
  cidr         = var.vpc_cidr
  az_count     = var.az_count
  enable_nat   = true
  cluster_name = var.cluster_name
}

module "cluster" {
  source = "../../modules/eks"

  name          = var.cluster_name
  k8s_version   = var.k8s_version
  subnet_ids    = module.network.private_subnet_ids
  node_type     = var.node_type
  node_disk_gb  = var.node_disk_gb
  node_min      = var.node_min
  node_desired  = var.node_desired
  node_max      = var.node_max
  node_max_pods = var.node_max_pods
}

module "database" {
  source   = "../../modules/rds"
  for_each = var.databases

  name              = "${var.name}-${each.key}"
  engine            = each.value.engine
  engine_version    = each.value.version
  port              = each.value.port
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.private_subnet_ids
  source_sg_id      = module.cluster.cluster_security_group_id
  instance_class    = var.db_instance_class
  disk_gb           = var.db_disk_gb
  max_disk_gb       = var.db_max_disk_gb
  username          = each.value.user
  password          = var.database_passwords[each.key]
  backup_days       = var.db_backup_days
  multi_az          = var.db_multi_az
  replicas          = var.db_replicas
  apply_immediately = var.db_apply_now
}

module "storage" {
  source   = "../../modules/s3"
  for_each = var.buckets

  name   = each.key
  public = each.value.public
}

module "registry" {
  source = "../../modules/ecr"

  repositories = var.repositories
  keep_images  = var.keep_images
  region       = var.region
}

module "identity" {
  source = "../../modules/identity"

  name              = var.name
  cluster_name      = module.cluster.cluster_name
  namespace         = var.k8s_namespace
  storage           = { for bucket, spec in var.buckets : spec.service => module.storage[bucket].arn }
  backup_bucket_arn = local.backup_bucket_arn
  backup_accounts   = var.backup_accounts
}

module "monitoring" {
  source = "../../modules/cloudwatch"

  name           = var.name
  log_groups     = ["/${var.name}/cluster"]
  retention_days = var.log_retention_days
  alarm_email    = var.alarm_email

  alarms = merge({}, [
    for database in keys(var.databases) : {
      "${database}-cpu" = {
        namespace  = "AWS/RDS"
        metric     = "CPUUtilization"
        threshold  = var.db_alarm_cpu
        dimensions = { DBInstanceIdentifier = "${var.name}-${database}" }
      }

      "${database}-disk" = {
        namespace  = "AWS/RDS"
        metric     = "FreeStorageSpace"
        threshold  = var.db_alarm_free_gb * 1000000000
        dimensions = { DBInstanceIdentifier = "${var.name}-${database}" }
        operator   = "LessThanThreshold"
      }
    }
  ]...)
}
