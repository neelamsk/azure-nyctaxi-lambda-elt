
# ---- environment identity ----
prefix   = "eltazr3"
location = "eastus2"

# ---- synapse admin ----
# Best practice: set password via environment or GitHub Actions secret:
#   TF_VAR_synapse_sql_admin_password
# synapse_sql_admin_login    = "synadmin"
# synapse_sql_admin_password = "<set via env/secret>"

# ---- spark (use defaults unless you need to change) ----
spark_node_family     = "MemoryOptimized"
spark_node_size       = "Small"
spark_min_nodes       = 3
spark_max_nodes       = 3
spark_auto_pause_mins = 15
spark_version         = "3.4"

# ---- networking (optional for dev firewall testing) ----
# client_ip = "66.234.34.103"

# ---- governance / purview ----
gov_rg_name                   = "eltazr3-governance-rg"
purview_account_name          = "pvw-eltazr3-dev"
enable_synapse_purview_browse = true


# ---- immutability (WORM) toggles by environment ----
# Dev: OFF (you’ll iterate/clean up frequently)
enable_worm = false
worm_days   = 3

# ---- tags (override if you want different labels for dev) ----
tags = {
  env   = "dev"
  owner = "da-project"
}

synapse_storage_account_type      = "LRS"
synapse_geo_backup_policy_enabled = false
