
resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
}

resource "azurerm_storage_account" "sa" {
  name                     = local.sa_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  blob_properties {
    # versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }

    # change_feed_enabled = true
  }
}

resource "azurerm_storage_data_lake_gen2_filesystem" "raw" {
  name               = local.fs_raw_name
  storage_account_id = azurerm_storage_account.sa.id
}

resource "azurerm_synapse_workspace" "syn" {
  name                             = local.syn_ws_name
  resource_group_name              = azurerm_resource_group.rg.name
  location                         = var.location
  sql_administrator_login          = var.synapse_sql_admin_login
  sql_administrator_login_password = var.synapse_sql_admin_password
  public_network_access_enabled    = true
  managed_virtual_network_enabled  = false

  identity {
    type = "SystemAssigned"
  }

  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.raw.id

  purview_id = azurerm_purview_account.pvw.id
}

resource "azurerm_synapse_sql_pool" "dw" {
  name                      = local.sql_pool_name
  synapse_workspace_id      = azurerm_synapse_workspace.syn.id
  sku_name                  = "DW100c"
  create_mode               = "Default"
  storage_account_type      = var.synapse_storage_account_type
  geo_backup_policy_enabled = var.synapse_geo_backup_policy_enabled
}


resource "azurerm_synapse_spark_pool" "sp" {
  name                 = local.spark_pool
  synapse_workspace_id = azurerm_synapse_workspace.syn.id

  node_size_family = var.spark_node_family
  node_size        = var.spark_node_size
  spark_version    = var.spark_version # e.g., "3.3"

  auto_scale {
    min_node_count = var.spark_min_nodes
    max_node_count = var.spark_max_nodes
  }
  auto_pause {
    delay_in_minutes = var.spark_auto_pause_mins
  }
}

resource "azurerm_data_factory" "adf" {
  name                = local.adf_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  identity { type = "SystemAssigned" }
}

# RBAC: Synapse MI -> Storage
resource "azurerm_role_assignment" "syn_to_storage" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.syn.identity[0].principal_id
}

# RBAC: ADF MI -> Storage
resource "azurerm_role_assignment" "adf_to_storage" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.adf.identity[0].principal_id
}

# RBAC: ADF MI -> Synapse (management plane)
resource "azurerm_role_assignment" "adf_to_synapse" {
  scope                = azurerm_synapse_workspace.syn.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_data_factory.adf.identity[0].principal_id
}

# Optional: Synapse firewall allow your IP
resource "azurerm_synapse_firewall_rule" "client" {
  count                = var.client_ip == null ? 0 : 1
  name                 = "AllowClientIP"
  synapse_workspace_id = azurerm_synapse_workspace.syn.id
  start_ip_address     = var.client_ip
  end_ip_address       = var.client_ip
}

# Look up the Blob container that backs your Gen2 filesystem "raw"
data "azurerm_storage_container" "raw_container" {
  name                 = azurerm_storage_data_lake_gen2_filesystem.raw.name # "raw"
  storage_account_name = azurerm_storage_account.sa.name
}

# Correct schema for azurerm ~> 3.100
resource "azurerm_storage_container_immutability_policy" "raw_worm" {
  count = var.enable_worm ? 1 : 0

  storage_container_resource_manager_id = data.azurerm_storage_container.raw_container.id
  immutability_period_in_days           = var.worm_days

  # Optional (usually false for lake patterns)
  # protected_append_writes_enabled = false
}