output "network_id" {
  value = google_compute_network.this.id
}

output "network_name" {
  value = google_compute_network.this.name
}

output "subnet_id" {
  value = google_compute_subnetwork.this.id
}

output "subnet_name" {
  value = google_compute_subnetwork.this.name
}
