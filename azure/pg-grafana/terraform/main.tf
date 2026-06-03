resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_password" "admin" {
  length           = 24
  special          = true
  override_special = "!#$%*-_=+"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# Burstable, minimum-spec dev instance:
#   B_Standard_B1ms = 1 vCore / 2 GiB RAM (smallest burstable tier)
#   32768 MB        = 32 GiB (smallest supported storage)
resource "azurerm_postgresql_flexible_server" "pg" {
  name                = "${var.prefix}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  version             = var.postgres_version

  administrator_login    = var.admin_username
  administrator_password = random_password.admin.result

  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

  auto_grow_enabled             = false
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = true

  lifecycle {
    # Azure may assign an availability zone we don't control; don't fight it.
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "client" {
  name             = "demo-client-access"
  server_id        = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = var.allowed_client_ip_start
  end_ip_address   = var.allowed_client_ip_end
}
