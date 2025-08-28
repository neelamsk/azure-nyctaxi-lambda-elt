
variable "prefix" { type = string }
variable "location" { type = string }

# Synapse SQL Admin (for the Dedicated SQL Pool)
variable "synapse_sql_admin_login" {
  type = string
}

variable "synapse_sql_admin_password" {
  type      = string
  sensitive = true
}
