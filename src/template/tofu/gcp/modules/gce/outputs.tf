output "public_ip" {
  value = google_compute_address.this.address
}

output "account_email" {
  value = google_service_account.node.email
}
