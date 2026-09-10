resource "google_artifact_registry_repository" "this" {
  location      = var.region
  repository_id = var.repository
  format        = "DOCKER"

  docker_config {
    immutable_tags = true
  }

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"

    most_recent_versions {
      keep_count = var.keep_images
    }
  }
}
