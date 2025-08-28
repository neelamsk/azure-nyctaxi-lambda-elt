output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  value = azurerm_storage_account.adls.name
}

output "adf_name" {
  value = azurerm_data_factory.adf.name
}

output "synapse_workspace_name" {
  value = azurerm_synapse_workspace.syn.name
}

output "synapse_sql_pool_name" {
  value = azurerm_synapse_sql_pool.sqlpool.name
}