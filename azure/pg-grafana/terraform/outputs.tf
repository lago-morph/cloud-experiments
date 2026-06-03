output "server_fqdn" {
  description = "Fully qualified domain name of the PostgreSQL server."
  value       = azurerm_postgresql_flexible_server.pg.fqdn
}

output "server_name" {
  description = "Name of the PostgreSQL flexible server."
  value       = azurerm_postgresql_flexible_server.pg.name
}

output "admin_username" {
  description = "PostgreSQL administrator login."
  value       = var.admin_username
}

output "admin_password" {
  description = "Generated PostgreSQL administrator password."
  value       = random_password.admin.result
  sensitive   = true
}

output "management_database" {
  description = "Built-in management database used to drive the demo load."
  value       = "postgres"
}

output "resource_group" {
  description = "Resource group containing the demo resources."
  value       = local.rg_name
}
