
variable "prefix" {
  type = string
}
variable "location" {
  type = string
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
  default = "None"
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

# Optional: allowlist your IP on Synapse firewall during dev
variable "client_ip" {
  type    = string
  default = null
}

variable "spark_version" {
  type    = string
  default = "3.3"
}
