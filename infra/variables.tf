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
