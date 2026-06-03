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

# Use an existing resource group when one is supplied (e.g. a locked-down lab
# subscription that only grants access to a pre-created RG); otherwise create
# one.
resource "azurerm_resource_group" "rg" {
  count    = var.existing_resource_group_name == "" ? 1 : 0
  name     = "${var.prefix}-rg"
  location = var.location
}

data "azurerm_resource_group" "existing" {
  count = var.existing_resource_group_name == "" ? 0 : 1
  name  = var.existing_resource_group_name
}

locals {
  rg_name     = var.existing_resource_group_name == "" ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.existing[0].name
  rg_location = var.existing_resource_group_name == "" ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.existing[0].location
}

# Burstable, minimum-spec dev instance:
#   B_Standard_B1ms = 1 vCore / 2 GiB RAM (smallest burstable tier)
#   32768 MB        = 32 GiB (smallest supported storage)
resource "azurerm_postgresql_flexible_server" "pg" {
  name                = "${var.prefix}-${random_string.suffix.result}"
  resource_group_name = local.rg_name
  location            = local.rg_location
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
