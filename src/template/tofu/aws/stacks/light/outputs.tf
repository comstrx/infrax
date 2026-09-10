output "server_ip" {
  value = module.server.public_ip
}

output "registry" {
  value = module.registry.registry
}

output "buckets" {
  value = [for bucket in module.storage : bucket.bucket]
}

output "backup_bucket" {
  value = var.backup_bucket
}
