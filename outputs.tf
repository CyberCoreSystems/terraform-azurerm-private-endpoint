output "id" {
  description = "Resource ID of the private endpoint."
  value       = azurerm_private_endpoint.this.id
}

output "name" {
  description = "Name of the private endpoint."
  value       = azurerm_private_endpoint.this.name
}

output "private_ip_address" {
  description = "Private IP address assigned to the endpoint's NIC from the subnet."
  value       = azurerm_private_endpoint.this.private_service_connection[0].private_ip_address
}

output "network_interface_id" {
  description = "Resource ID of the network interface Azure created for the endpoint."
  value       = azurerm_private_endpoint.this.network_interface[0].id
}

output "custom_dns_configs" {
  description = "List of { fqdn, ip_addresses } the endpoint resolves to — use these to populate DNS if you are not using a linked private DNS zone."
  value       = azurerm_private_endpoint.this.custom_dns_configs
}

output "subnet_id" {
  description = "Resource ID of the subnet the endpoint's NIC lives in (module-created or caller-supplied)."
  value       = local.subnet_id
}

output "target_resource_id" {
  description = "Resource ID of the PaaS resource the endpoint connects to (module-created demo target or caller-supplied)."
  value       = local.target_resource_id
}

output "virtual_network_id" {
  description = "Resource ID of the module-created virtual network (null when consuming an existing subnet)."
  value       = one(azurerm_virtual_network.this[*].id)
}

output "private_dns_zone_id" {
  description = "Resource ID of the module-created private DNS zone (null when none was created)."
  value       = one(azurerm_private_dns_zone.this[*].id)
}

output "demo_storage_account_id" {
  description = "Resource ID of the module-created demo Storage Account target (null unless create_demo_target = true)."
  value       = one(azurerm_storage_account.demo[*].id)
}

output "demo_storage_account_name" {
  description = "Name of the module-created demo Storage Account target (null unless create_demo_target = true)."
  value       = one(azurerm_storage_account.demo[*].name)
}
