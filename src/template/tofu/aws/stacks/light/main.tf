locals {
  backup_bucket_arn = "arn:aws:s3:::${var.backup_bucket}"
}

module "network" {
  source = "../../modules/network"

  name       = var.name
  cidr       = var.vpc_cidr
  az_count   = var.az_count
  enable_nat = false
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

module "server" {
  source = "../../modules/ec2"

  name                = var.name
  vpc_id              = module.network.vpc_id
  subnet_id           = module.network.public_subnet_ids[0]
  instance_type       = var.ec2_type
  disk_gb             = var.ec2_disk_gb
  ubuntu_version      = var.ec2_ubuntu
  admin_cidrs         = var.admin_cidrs
  ssh_public_key      = var.ssh_public_key
  ecr_arns            = module.registry.repository_arns
  storage_bucket_arns = [for bucket in module.storage : bucket.arn]
  backup_bucket_arn   = local.backup_bucket_arn
}
