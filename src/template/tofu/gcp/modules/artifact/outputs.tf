output "registry" {
  value = "${var.region}-docker.pkg.dev/${var.project}"
}

output "repository" {
  value = google_artifact_registry_repository.this.repository_id
}
