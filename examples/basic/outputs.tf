output "private_endpoint_id" {
  description = "Resource ID of the private endpoint created by the example."
  value       = module.private_endpoint.id
}

output "private_ip_address" {
  description = "Private IP the endpoint received from the module-created subnet."
  value       = module.private_endpoint.private_ip_address
}

output "demo_storage_account_id" {
  description = "Resource ID of the demo Storage Account target."
  value       = module.private_endpoint.demo_storage_account_id
}
