output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.k8s.name
}

output "control_plane_public_ip" {
  description = "Public IP address of the control plane"
  value       = azurerm_public_ip.control_plane.ip_address
}

output "worker_public_ips" {
  description = "Public IP addresses of worker nodes"
  value       = azurerm_public_ip.worker[*].ip_address
}

output "load_balancer_public_ip" {
  description = "Public IP address of the load balancer"
  value       = azurerm_public_ip.lb.ip_address
}

output "control_plane_private_ip" {
  description = "Private IP address of the control plane"
  value       = azurerm_network_interface.control_plane.private_ip_address
}

output "worker_private_ips" {
  description = "Private IP addresses of worker nodes"
  value       = azurerm_network_interface.worker[*].private_ip_address
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.k8s.name
}

output "storage_account_primary_key" {
  description = "Primary access key for storage account"
  value       = azurerm_storage_account.k8s.primary_access_key
  sensitive   = true
}

output "storage_account_connection_string" {
  description = "Connection string for storage account"
  value       = azurerm_storage_account.k8s.primary_connection_string
  sensitive   = true
}

output "storage_container_name" {
  description = "Name of the storage container"
  value       = azurerm_storage_container.k8s.name
}

output "ssh_command_control_plane" {
  description = "SSH command to connect to control plane"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.control_plane.ip_address}"
}

output "ssh_commands_workers" {
  description = "SSH commands to connect to worker nodes"
  value = [
    for i, ip in azurerm_public_ip.worker[*].ip_address :
    "ssh ${var.admin_username}@${ip}"
  ]
}

output "control_plane_identity_principal_id" {
  description = "Principal ID of control plane managed identity"
  value       = azurerm_linux_virtual_machine.control_plane.identity[0].principal_id
}

output "worker_identity_principal_ids" {
  description = "Principal IDs of worker nodes managed identities"
  value       = [for vm in azurerm_linux_virtual_machine.worker : vm.identity[0].principal_id]
}
