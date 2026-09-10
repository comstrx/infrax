resource "google_compute_network" "this" {
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  name                     = var.name
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.cidr
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = var.secondary_ranges

    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }
}

resource "google_compute_router" "this" {
  count = var.enable_nat ? 1 : 0

  name    = var.name
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  count = var.enable_nat ? 1 : 0

  name                               = var.name
  router                             = google_compute_router.this[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "web" {
  count = var.open_web ? 1 : 0

  name          = "${var.name}-web"
  network       = google_compute_network.this.name
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_firewall" "ssh" {
  count = var.open_ssh ? 1 : 0

  name          = "${var.name}-ssh"
  network       = google_compute_network.this.name
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "api" {
  count = length(var.admin_cidrs) > 0 ? 1 : 0

  name          = "${var.name}-api"
  network       = google_compute_network.this.name
  source_ranges = var.admin_cidrs
  target_tags   = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }
}
