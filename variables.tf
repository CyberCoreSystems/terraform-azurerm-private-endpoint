variable "name" {
  description = "Name of the private endpoint. Also the base name for any module-created VNet/subnet (vnet-<name>/snet-<name>) and private DNS link."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]{0,78}[a-zA-Z0-9_]$", var.name))
    error_message = "name must be 2-80 chars: letters, digits, '.', '_' or '-'; start alphanumeric and end alphanumeric or underscore."
  }
}

variable "resource_group_name" {
  description = "Name of an EXISTING resource group. The private endpoint (and any module-created VNet/subnet/demo target) are created in it. This module does not create or destroy the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for the private endpoint and any module-created resources (e.g. eastus2, westeurope)."
  type        = string
}

# -----------------------------------------------------------------------------
# Target PaaS resource (the thing the private endpoint connects to)
# -----------------------------------------------------------------------------

variable "target_resource_id" {
  description = "Resource ID of the EXISTING PaaS resource to expose privately (e.g. a Storage Account, Key Vault, SQL Server). Leave null and set create_demo_target = true to have the module stand up its own demo Storage Account target (useful for self-contained testing)."
  type        = string
  default     = null
}

variable "subresource_names" {
  description = "Subresource (group ID) names to connect to on the target — e.g. [\"blob\"], [\"file\"], [\"dfs\"] for Storage; [\"vault\"] for Key Vault; [\"sqlServer\"] for Azure SQL; [\"sites\"] for App Service. Defaults to [\"blob\"], which matches the built-in demo Storage Account target."
  type        = list(string)
  default     = ["blob"]

  validation {
    condition     = length(var.subresource_names) > 0
    error_message = "subresource_names must list at least one group ID (e.g. [\"blob\"] for Storage, [\"vault\"] for Key Vault)."
  }
}

variable "is_manual_connection" {
  description = "Request a manual (approval-required) private link connection instead of auto-approval. Use this when connecting to a target you do not own (cross-tenant / cross-subscription); the target owner must approve the request."
  type        = bool
  default     = false
}

variable "request_message" {
  description = "Optional approval request message shown to the target owner. Only used when is_manual_connection = true (max 140 chars)."
  type        = string
  default     = null

  validation {
    condition     = var.request_message == null ? true : length(var.request_message) <= 140
    error_message = "request_message must be 140 characters or fewer."
  }
}

variable "custom_network_interface_name" {
  description = "Override the name Azure gives the private endpoint's NIC. Null lets Azure auto-name it."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Networking — consume an existing subnet, or have the module create one
# -----------------------------------------------------------------------------

variable "subnet_id" {
  description = "Resource ID of the EXISTING subnet the private endpoint's NIC is placed in. Leave null and set create_network = true to have the module create a dedicated VNet + subnet. The subnet must allow private endpoints (private_endpoint_network_policies handled automatically for module-created subnets)."
  type        = string
  default     = null
}

variable "create_network" {
  description = "Create a dedicated VNet + subnet for the private endpoint instead of consuming an existing subnet_id. The module-created subnet sets private_endpoint_network_policies = \"Disabled\" so endpoints can be attached."
  type        = bool
  default     = false
}

variable "vnet_address_space" {
  description = "Address space for the module-created virtual network (only used when create_network = true)."
  type        = list(string)
  default     = ["10.60.0.0/16"]
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the module-created subnet (only used when create_network = true; must fall within vnet_address_space)."
  type        = list(string)
  default     = ["10.60.1.0/24"]
}

# -----------------------------------------------------------------------------
# Demo target — a self-contained Storage Account to point the endpoint at
# -----------------------------------------------------------------------------

variable "create_demo_target" {
  description = "Create a locked-down demo Storage Account (public access OFF, keys OFF, TLS 1.2+, infrastructure encryption ON) and point the private endpoint at it. Makes the module self-contained for testing. Set target_resource_id instead for real use."
  type        = bool
  default     = false
}

variable "demo_storage_account_name" {
  description = "Name for the demo Storage Account (3-24 lowercase alphanumerics, globally unique). Null derives a unique name from a random suffix. Only used when create_demo_target = true."
  type        = string
  default     = null

  validation {
    condition     = var.demo_storage_account_name == null ? true : can(regex("^[a-z0-9]{3,24}$", var.demo_storage_account_name))
    error_message = "demo_storage_account_name must be 3-24 lowercase letters and digits."
  }
}

# -----------------------------------------------------------------------------
# Private DNS — optional zone + A-record integration for name resolution
# -----------------------------------------------------------------------------

variable "private_dns_zone_ids" {
  description = "Resource IDs of EXISTING private DNS zones to register the endpoint's A record(s) in (e.g. the privatelink.blob.core.windows.net zone). Combined with a module-created zone when create_private_dns_zone = true."
  type        = list(string)
  default     = []
}

variable "create_private_dns_zone" {
  description = "Create a private DNS zone (named private_dns_zone_name) and, when create_network = true, link it to the module-created VNet. The endpoint's records are registered in it automatically."
  type        = bool
  default     = false
}

variable "private_dns_zone_name" {
  description = "FQDN of the private DNS zone to create (e.g. \"privatelink.blob.core.windows.net\"). Required when create_private_dns_zone = true."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
