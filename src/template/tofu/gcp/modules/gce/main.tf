resource "google_service_account" "node" {
  account_id   = substr("${var.name}-node", 0, 30)
  display_name = "${var.name} node"
}

resource "google_compute_address" "this" {
  name   = var.name
  region = var.region
}

resource "google_compute_instance" "this" {
  name                      = var.name
  machine_type              = var.machine_type
  zone                      = var.zone
  tags                      = [var.name]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnet_id

    access_config {
      nat_ip = google_compute_address.this.address
    }
  }

  metadata = {
    ssh-keys               = "${var.ssh_user}:${var.ssh_public_key}"
    block-project-ssh-keys = "true"
  }

  service_account {
    email  = google_service_account.node.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]

    precondition {
      condition     = var.ssh_public_key != ""
      error_message = "SSH_PUBLIC_KEY is required — a keyless box has no management path."
    }
  }
}

resource "google_artifact_registry_repository_iam_member" "pull" {
  project    = var.project
  location   = var.region
  repository = var.repository
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.node.email}"
}

resource "google_storage_bucket_iam_member" "storage" {
  for_each = toset(var.buckets)

  bucket = each.value
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.node.email}"
}

resource "google_storage_bucket_iam_member" "backups" {
  bucket = var.backup_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.node.email}"
}
