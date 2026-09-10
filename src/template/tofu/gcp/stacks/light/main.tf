module "network" {
  source = "../../modules/network"

  name        = var.name
  region      = var.region
  cidr        = var.vpc_cidr
  open_web    = true
  open_ssh    = true
  admin_cidrs = var.admin_cidrs
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

module "server" {
  source = "../../modules/gce"

  name           = var.name
  project        = var.project
  region         = var.region
  zone           = var.zone
  subnet_id      = module.network.subnet_id
  machine_type   = var.machine_type
  disk_gb        = var.disk_gb
  image          = var.image
  ssh_user       = var.ssh_user
  ssh_public_key = var.ssh_public_key
  repository     = module.registry.repository
  buckets        = module.storage.names
  backup_bucket  = var.backup_bucket
}
