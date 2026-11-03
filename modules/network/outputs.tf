output "vnet_id" {
  description = "ID du Virtual Network"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Nom du Virtual Network"
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "IDs des sous-réseaux, indexés par rôle (web, db...)"
  value       = { for key, subnet in azurerm_subnet.this : key => subnet.id }
}

output "subnet_address_prefixes" {
  description = "CIDR des sous-réseaux, indexés par rôle"
  value       = { for key, subnet in azurerm_subnet.this : key => subnet.address_prefixes[0] }
}
