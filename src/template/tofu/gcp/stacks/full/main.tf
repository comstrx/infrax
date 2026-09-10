module "network" {
  source = "../../modules/network"

  name       = var.name
  region     = var.region
  cidr       = var.vpc_cidr
  enable_nat = true

  secondary_ranges = {
    pods     = var.pods_cidr
    services = var.services_cidr
  }
}

module "registry" {
  source = "../../modules/artifact"

  project     = var.project
  region      = var.region
  repository  = var.repository
  keep_images = var.keep_images
}

module "storage" {
  source = "../../modules/gcs"

  region  = var.region
  buckets = var.buckets
}

module "cluster" {
  source = "../../modules/gke"

  name         = var.cluster_name
  project      = var.project
  region       = var.region
  zone         = var.zone
  network      = module.network.network_id
  subnet       = module.network.subnet_id
  node_type    = var.node_type
  node_disk_gb = var.node_disk_gb
  node_min     = var.node_min
  node_max     = var.node_max
  admin_cidrs  = var.admin_cidrs
}

module "database" {
  source = "../../modules/cloudsql"
  count  = length(var.databases) > 0 ? 1 : 0

  name        = var.name
  region      = var.region
  network     = module.network.network_id
  databases   = var.databases
  passwords   = var.database_passwords
  tier        = var.db_tier
  disk_gb     = var.db_disk_gb
  backup_days = var.db_backup_days
  multi_az    = var.db_multi_az
}

module "identity" {
  source = "../../modules/identity"

  namespace       = var.k8s_namespace
  workload_pool   = module.cluster.workload_pool
  buckets         = var.buckets
  backup_bucket   = var.backup_bucket
  backup_accounts = var.backup_accounts

  depends_on = [module.storage]
}
