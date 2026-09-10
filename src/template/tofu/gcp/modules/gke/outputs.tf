output "cluster_name" {
  value = google_container_cluster.this.name
}

output "cluster_endpoint" {
  value = "https://${google_container_cluster.this.endpoint}"
}

output "workload_pool" {
  value = google_container_cluster.this.workload_identity_config[0].workload_pool
}
