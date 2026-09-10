resource "google_storage_bucket" "this" {
  for_each = var.buckets

  name                        = each.key
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = each.value.public ? "inherited" : "enforced"

  lifecycle_rule {
    action {
      type = "AbortIncompleteMultipartUpload"
    }

    condition {
      age = 7
    }
  }
}

resource "google_storage_bucket_iam_member" "public" {
  for_each = { for name, spec in var.buckets : name => spec if spec.public }

  bucket = google_storage_bucket.this[each.key].name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
