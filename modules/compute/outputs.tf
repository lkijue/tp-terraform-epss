output "lb_public_ip" {
  description = "Adresse IP publique du Load Balancer"
  value       = azurerm_public_ip.lb.ip_address
}

output "lb_fqdn" {
  description = "Nom DNS du Load Balancer"
  value       = azurerm_public_ip.lb.fqdn
}

output "web_vm_names" {
  description = "Noms des VMs web"
  value       = azurerm_linux_virtual_machine.web[*].name
}

output "web_private_ips" {
  description = "IPs privées des VMs web"
  value       = azurerm_network_interface.web[*].private_ip_address
}

output "web_ssh_ports" {
  description = "Port SSH (sur l'IP du Load Balancer) de chaque VM web"
  value       = [for i in range(var.web_vm_count) : local.ssh_nat_base_port + i + 1]
}

output "db_private_ip" {
  description = "IP privée de la VM db"
  value       = azurerm_network_interface.db.private_ip_address
}

output "storage_account_name" {
  description = "Storage Account des diagnostics"
  value       = azurerm_storage_account.diag.name
}
