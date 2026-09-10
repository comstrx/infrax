resource "google_compute_global_address" "private" {
  name          = "${var.name}-sql"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network
}

resource "google_service_networking_connection" "this" {
  network                 = var.network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private.name]
}

resource "google_sql_database_instance" "this" {
  for_each = var.databases

  name                = "${var.name}-${each.key}"
  region              = var.region
  database_version    = each.value.version
  deletion_protection = true

  settings {
    tier                        = var.tier
    disk_size                   = var.disk_gb
    disk_autoresize             = true
    availability_type           = var.multi_az ? "REGIONAL" : "ZONAL"
    deletion_protection_enabled = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = startswith(each.value.version, "POSTGRES")
      binary_log_enabled             = startswith(each.value.version, "MYSQL")

      backup_retention_settings {
        retained_backups = var.backup_days
      }
    }
  }

  depends_on = [google_service_networking_connection.this]
}

resource "google_sql_user" "root" {
  for_each = var.databases

  name     = each.value.user
  instance = google_sql_database_instance.this[each.key].name
  password = var.passwords[each.key]
  host     = startswith(each.value.version, "MYSQL") ? "%" : null
}
