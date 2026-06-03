variable "location" {
  type        = string
  description = "Azure region for the demo resources."
  default     = "eastus"
}

variable "prefix" {
  type        = string
  description = "Name prefix for all resources."
  default     = "pgdemo"
}

variable "admin_username" {
  type        = string
  description = "PostgreSQL administrator login."
  default     = "pgadmin"
}

variable "postgres_version" {
  type        = string
  description = "Major PostgreSQL version."
  default     = "16"
}

# For the demo we open the firewall wide so the (ephemeral) container host can
# reach the server. Tighten these to a specific IP for anything real.
variable "allowed_client_ip_start" {
  type        = string
  description = "Start of the allowed client IP range for the server firewall."
  default     = "0.0.0.0"
}

variable "allowed_client_ip_end" {
  type        = string
  description = "End of the allowed client IP range for the server firewall."
  default     = "255.255.255.255"
}
