output "nsg_ids" {
  description = "IDs des NSG, indexés par rôle"
  value       = { for role, nsg in azurerm_network_security_group.this : role => nsg.id }
}

output "key_vault_name" {
  description = "Nom du Key Vault"
  value       = azurerm_key_vault.this.name
  # La VM db ne doit démarrer qu'une fois son droit de lecture en place.
  depends_on = [azurerm_key_vault_access_policy.db_identity]
}

output "db_password_secret_name" {
  description = "Nom du secret contenant le mot de passe PostgreSQL"
  value       = azurerm_key_vault_secret.db_password.name
}

output "db_identity_id" {
  description = "ID de l'identité managée de la VM db"
  value       = azurerm_user_assigned_identity.db.id
}

output "db_identity_client_id" {
  description = "Client ID de l'identité managée de la VM db"
  value       = azurerm_user_assigned_identity.db.client_id
}
