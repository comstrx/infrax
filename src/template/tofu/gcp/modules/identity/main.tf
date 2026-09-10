locals {
  storage = { for bucket, spec in var.buckets : spec.service => merge(spec, { bucket = bucket }) }
}

resource "google_service_account" "storage" {
  for_each = local.storage

  account_id   = each.value.account
  display_name = "${each.key} storage"
}

resource "google_storage_bucket_iam_member" "storage" {
  for_each = local.storage

  bucket = each.value.bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.storage[each.key].email}"
}

resource "google_service_account_iam_member" "storage" {
  for_each = local.storage

  service_account_id = google_service_account.storage[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.workload_pool}[${var.namespace}/${each.key}]"
}

resource "google_service_account" "backup" {
  for_each = var.backup_accounts

  account_id   = each.value
  display_name = "${each.key} backups"
}

resource "google_storage_bucket_iam_member" "backup" {
  for_each = var.backup_accounts

  bucket = var.backup_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.backup[each.key].email}"
}

resource "google_service_account_iam_member" "backup" {
  for_each = var.backup_accounts

  service_account_id = google_service_account.backup[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.workload_pool}[${var.namespace}/${each.key}]"
}
