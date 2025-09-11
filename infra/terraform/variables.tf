
variable "prefix" {
  type = string
}
variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

# Synapse SQL Admin (for the Dedicated SQL Pool)
variable "synapse_sql_admin_login" {
  type = string
}

variable "synapse_sql_admin_password" {
  type      = string
  sensitive = true
}


# Optional tunables (safe defaults are OK here)
variable "spark_node_family" {
  type    = string
  default = "MemoryOptimized"
} # or "MemoryOptimized"


variable "spark_node_size" {
  type    = string
  default = "Small"
}

variable "spark_min_nodes" {
  type    = number
  default = 3
}

variable "spark_max_nodes" {
  type    = number
  default = 3
}

variable "spark_auto_pause_mins" {
  type    = number
  default = 15
}

# allowlist your IP on Synapse firewall during dev
variable "client_ip" {
  type    = string
  default = null
}

variable "spark_version" {
  type    = string
  default = "3.3"
}


# Purview governance related vairables
variable "gov_rg_name" {
  description = "Resource group for governance (Purview)"
  type        = string
  default     = "eltazr3-governance-rg"
}

variable "purview_account_name" {
  description = "Purview account name (globally unique in tenant)"
  type        = string
  default     = "pvw-eltazr3-dev"
}

variable "enable_synapse_purview_browse" {
  description = "Grant Synapse MI Purview Data Reader so it can browse the catalog"
  type        = bool
  default     = true
}


variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    env   = "dev"
    owner = "da-project"
  }
}