######################
# Naming helpers
######################
locals {
  base                    = lower(replace(var.prefix, "-", ""))
  storage_account_name    = substr("${local.base}adls", 0, 24) # 3-24 chars, lowercase, no dashes
  storage_filesystem_name = "synapse"
}

######################
# Resource Group
######################
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

######################
# Storage (ADLS Gen2)
######################
resource "azurerm_storage_account" "adls" {
  name                            = local.storage_account_name
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  is_hns_enabled                  = true
  allow_nested_items_to_be_public = false
}

# Raw container for landings
resource "azurerm_storage_container" "raw" {
  name                  = "raw"
  storage_account_name  = azurerm_storage_account.adls.name
  container_access_type = "private"
}

# Filesystem that Synapse workspace uses
resource "azurerm_storage_data_lake_gen2_filesystem" "wsfs" {
  name               = local.storage_filesystem_name
  storage_account_id = azurerm_storage_account.adls.id
}


######################
# Synapse Workspace + Dedicated SQL Pool
######################
resource "azurerm_synapse_workspace" "syn" {
  name                                 = "${var.prefix}-syn"
  resource_group_name                  = azurerm_resource_group.rg.name
  location                             = azurerm_resource_group.rg.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.wsfs.id

  sql_administrator_login    = var.synapse_sql_admin_login
  sql_administrator_login_password = var.synapse_sql_admin_password

  identity { type = "SystemAssigned" }
}

# Allow Azure Services (0.0.0.0) 
resource "azurerm_synapse_firewall_rule" "allow_azure" {
  name                 = "AllowAllWindowsAzureIps"
  synapse_workspace_id = azurerm_synapse_workspace.syn.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "0.0.0.0"
}

resource "azurerm_synapse_sql_pool" "sqlpool" {
  name                 = "${var.prefix}_sqlpool"
  synapse_workspace_id = azurerm_synapse_workspace.syn.id
  sku_name             = "DW100c"
  create_mode          = "Default"
}


######################
# Azure Data Factory (MI)
######################
resource "azurerm_data_factory" "adf" {
  name                = "${var.prefix}-adf"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  identity { type = "SystemAssigned" }
}


######################
# RBAC access for ADF and Synapse access to the storage
######################
resource "azurerm_role_assignment" "adf_to_storage_rbac" {
  scope                = azurerm_storage_account.adls.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.adf.identity[0].principal_id
}

resource "azurerm_role_assignment" "synapse_to_storage_rbac" {
  scope                = azurerm_storage_account.adls.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.syn.identity[0].principal_id
}