output "addresses" {
  value = { for name, database in google_sql_database_instance.this : name => database.private_ip_address }
}
