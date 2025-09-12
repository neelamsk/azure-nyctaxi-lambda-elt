output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "synapse_sql_pool_name" {
  value = azurerm_synapse_sql_pool.dw.name
}

output "spark_pool_name" {
  value = azurerm_synapse_spark_pool.sp.name
}

output "synapse_workspace_name" {
  value = azurerm_synapse_workspace.syn.name
}

output "data_factory_name" {
  value = azurerm_data_factory.adf.name
}

output "purview_principal_id" {
  value = azurerm_purview_account.pvw.identity[0].principal_id
}

output "adf_principal_id" {
  value = azurerm_data_factory.adf.identity[0].principal_id
}

output "purview_endpoint" {
  value = "https://${var.purview_account_name}.purview.azure.com"
}
