output "resource_group_name" {
  description = "Resource Group de l'environnement"
  value       = azurerm_resource_group.this.name
}

output "lb_public_ip" {
  description = "IP publique du Load Balancer"
  value       = module.compute.lb_public_ip
}

output "website_url" {
  description = "URL du site (via le Load Balancer)"
  value       = "http://${module.compute.lb_fqdn}"
}

output "ssh_commands" {
  description = "Commandes SSH vers chaque VM web (via le NAT du Load Balancer)"
  value = [
    for port in module.compute.web_ssh_ports :
    "ssh -p ${port} ${var.admin_username}@${module.compute.lb_public_ip}"
  ]
}

output "ssh_db_command" {
  description = "SSH vers la VM db en rebondissant par web-1 (la db n'est pas exposée)"
  value       = "ssh -J ${var.admin_username}@${module.compute.lb_public_ip}:${module.compute.web_ssh_ports[0]} ${var.admin_username}@${module.compute.db_private_ip}"
}

output "subnet_ids" {
  description = "IDs des sous-réseaux"
  value       = module.network.subnet_ids
}

output "web_private_ips" {
  description = "IPs privées des VMs web"
  value       = module.compute.web_private_ips
}

output "db_private_ip" {
  description = "IP privée de la VM db"
  value       = module.compute.db_private_ip
}

output "key_vault_name" {
  description = "Key Vault contenant le mot de passe PostgreSQL"
  value       = module.security.key_vault_name
}
