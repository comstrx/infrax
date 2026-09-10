resource "google_service_account" "node" {
  account_id   = substr("${var.name}-gke", 0, 30)
  display_name = "${var.name} gke node"
}

resource "google_project_iam_member" "node" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])

  project = var.project
  role    = each.value
  member  = "serviceAccount:${google_service_account.node.email}"
}

resource "google_container_cluster" "this" {
  name           = var.name
  location       = var.region
  node_locations = [var.zone]
  network        = var.network
  subnetwork     = var.subnet

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = true
  networking_mode          = "VPC_NATIVE"
  datapath_provider        = "ADVANCED_DATAPATH"

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.project}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(var.admin_cidrs) > 0 ? [1] : []

    content {
      dynamic "cidr_blocks" {
        for_each = var.admin_cidrs

        content {
          cidr_block = cidr_blocks.value
        }
      }
    }
  }
}

resource "google_container_node_pool" "this" {
  name     = "${var.name}-pool"
  cluster  = google_container_cluster.this.id
  location = var.region

  autoscaling {
    min_node_count = var.node_min
    max_node_count = var.node_max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_type
    disk_size_gb    = var.node_disk_gb
    disk_type       = "pd-balanced"
    service_account = google_service_account.node.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}
