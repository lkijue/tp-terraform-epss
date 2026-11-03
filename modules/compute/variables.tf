variable "project" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement : dev, staging ou prod"
  type        = string
}

variable "name_prefix" {
  description = "Préfixe de nommage, ex : cloudtech-dev"
  type        = string
}

variable "short_name_prefix" {
  description = "Préfixe court et unique pour les noms globaux (storage, DNS)"
  type        = string
}

variable "location" {
  description = "Région Azure"
  type        = string
}

variable "resource_group_name" {
  description = "Nom du Resource Group cible"
  type        = string
}

variable "web_subnet_id" {
  description = "ID du sous-réseau des VMs web"
  type        = string
}

variable "web_subnet_prefix" {
  description = "CIDR du sous-réseau web (autorisé à joindre PostgreSQL)"
  type        = string
}

variable "db_subnet_id" {
  description = "ID du sous-réseau de la VM db"
  type        = string
}

variable "web_vm_count" {
  description = "Nombre de VMs web derrière le Load Balancer"
  type        = number
  default     = 2

  validation {
    condition     = var.web_vm_count >= 1 && var.web_vm_count <= 5
    error_message = "web_vm_count doit être compris entre 1 et 5."
  }
}

variable "web_vm_size" {
  description = "Taille des VMs web"
  type        = string
  default     = "Standard_B1s"
}

variable "db_vm_size" {
  description = "Taille de la VM db"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Utilisateur administrateur des VMs"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "Clé publique SSH (contenu du fichier .pub)"
  type        = string

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256) ", var.ssh_public_key))
    error_message = "ssh_public_key doit être le contenu d'une clé publique SSH (commence par ssh-ed25519 ou ssh-rsa)."
  }
}

variable "db_identity_id" {
  description = "ID de l'identité managée attachée à la VM db"
  type        = string
}

variable "db_identity_client_id" {
  description = "Client ID de l'identité managée de la VM db"
  type        = string
}

variable "key_vault_name" {
  description = "Nom du Key Vault contenant le mot de passe PostgreSQL"
  type        = string
}

variable "db_password_secret_name" {
  description = "Nom du secret contenant le mot de passe PostgreSQL"
  type        = string
}

variable "alert_email" {
  description = "E-mail qui reçoit les alertes CPU. Vide = monitoring désactivé."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags appliqués aux ressources"
  type        = map(string)
  default     = {}
}
