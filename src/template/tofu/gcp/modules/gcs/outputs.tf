output "names" {
  value = [for bucket in google_storage_bucket.this : bucket.name]
}
