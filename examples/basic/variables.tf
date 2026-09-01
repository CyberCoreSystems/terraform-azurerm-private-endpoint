variable "resource_group_name" {
  description = "Existing resource group to deploy the example into."
  type        = string
  default     = "rg-private-endpoint-example"
}

variable "location" {
  description = "Azure region for the example."
  type        = string
  default     = "eastus2"
}
