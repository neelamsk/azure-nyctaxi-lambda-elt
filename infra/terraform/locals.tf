locals {
  rg_name         = "${var.prefix}-rg"
  sa_name         = "${var.prefix}adls" # must be globally unique, lowercase
  fs_raw_name     = "raw"
  fs_synapse_name = "synapse"
  syn_ws_name     = "${var.prefix}-syn"
  sql_pool_name   = "${var.prefix}_sqlpool"
  spark_pool      = "spsmall"
  adf_name        = "${var.prefix}-adf"
}