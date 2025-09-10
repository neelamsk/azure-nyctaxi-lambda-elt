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