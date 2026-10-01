variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "project" {
  description = "Project name used in resource names and tags"
  type        = string
  default     = "trip-tracker"
}

variable "vnet_cidr" {
  description = "Address space for the project virtual network"
  type        = string
  default     = "10.20.0.0/16"
}

variable "admin_ip_cidr" {
  description = "Home public IP allowed to SSH to the jump box, in CIDR form (x.x.x.x/32)"
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_ip_cidr, 0))
    error_message = "admin_ip_cidr must be a valid CIDR block, for example 203.0.113.10/32."
  }
}

variable "admin_object_id" {
  description = "Entra ID object ID of the human admin who manages Key Vault secrets"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.admin_object_id))
    error_message = "admin_object_id must be a GUID, e.g. 00000000-0000-0000-0000-000000000000."
  }
}
