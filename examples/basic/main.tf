provider "azurerm" {
  features {}

  # The demo target Storage Account has shared keys disabled, so the provider
  # must use Entra ID (AAD) for any data-plane interaction.
  storage_use_azuread = true
}

# Self-contained example: the module builds its own VNet + subnet AND a
# locked-down demo Storage Account, then wires a blob private endpoint to it.
# Only an existing resource group + region are required.
module "private_endpoint" {
  source = "../../"

  name                = "pe-example-blob"
  resource_group_name = var.resource_group_name
  location            = var.location

  create_network     = true
  create_demo_target = true
  subresource_names  = ["blob"]

  tags = {
    environment = "example"
    managed_by  = "iac-bazaar"
  }
}
