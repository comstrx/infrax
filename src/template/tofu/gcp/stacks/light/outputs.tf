output "server_ip" {
  value = module.server.public_ip
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
