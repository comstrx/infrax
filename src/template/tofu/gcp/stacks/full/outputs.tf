output "cluster_name" {
  value = module.cluster.cluster_name
}

output "cluster_endpoint" {
  value = module.cluster.cluster_endpoint
}

output "registry" {
  value = module.registry.registry
}

output "buckets" {
  value = module.storage.names
}

output "backup_bucket" {
  value = var.backup_bucket
}

output "database_addresses" {
  value = length(module.database) > 0 ? module.database[0].addresses : {}
}
