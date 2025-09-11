# Resource Group for governance (best practice). If you prefer, you can
# point this to your existing RG by replacing this resource with a data source.
resource "azurerm_resource_group" "gov" {
  name     = var.gov_rg_name
  location = var.location
  tags     = var.tags
}

# Microsoft Purview (governance) account
resource "azurerm_purview_account" "pvw" {
  name                = var.purview_account_name
  resource_group_name = azurerm_resource_group.gov.name
  location            = var.location
  identity { type = "SystemAssigned" }

  # Purview needs a managed resource group (created & owned by the service)
  managed_resource_group_name = "${var.purview_account_name}-managed-rg"

  tags = var.tags
}

# -------- RBAC to let Purview scan ADLS Gen2 --------
# Purview MI needs data-plane read of your lake + control-plane read of the SA.
resource "azurerm_role_assignment" "pvw_sa_blob_reader" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_purview_account.pvw.identity[0].principal_id
}

resource "azurerm_role_assignment" "pvw_sa_reader" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Reader"
  principal_id         = azurerm_purview_account.pvw.identity[0].principal_id
}

# -------- RBAC to let ADF emit lineage to Purview --------
# Grant ADF's managed identity Data Curator on the Purview account.
resource "azurerm_role_assignment" "adf_pvw_curator" {
  scope                = azurerm_purview_account.pvw.id
  role_definition_name = "Purview Data Curator"
  principal_id         = azurerm_data_factory.adf.identity[0].principal_id
}

# Synapse can browse catalog; Reader is usually enough:
resource "azurerm_role_assignment" "syn_pvw_reader" {
  count                = var.enable_synapse_purview_browse ? 1 : 0
  scope                = azurerm_purview_account.pvw.id
  role_definition_name = "Purview Data Reader"
  principal_id         = azurerm_synapse_workspace.syn.identity[0].principal_id
}
