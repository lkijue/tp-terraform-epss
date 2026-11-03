variable "name_prefix" {
  description = "Préfixe de nommage, ex : cloudtech-dev"
  type        = string
}

variable "short_name_prefix" {
  description = "Préfixe court et unique (ressources à nom global limité à 24 caractères), ex : cloudtech-dev-a1b2c"
  type        = string

  validation {
    condition     = length(var.short_name_prefix) <= 21
    error_message = "short_name_prefix doit faire 21 caractères max (nom Key Vault = kv- + préfixe <= 24)."
  }
}

variable "location" {
  description = "Région Azure"
  type        = string
}

variable "resource_group_name" {
  description = "Nom du Resource Group cible"
  type        = string
}

variable "subnet_ids" {
  description = "IDs des sous-réseaux (doit contenir les clés web et db)"
  type        = map(string)

  validation {
    condition     = contains(keys(var.subnet_ids), "web") && contains(keys(var.subnet_ids), "db")
    error_message = "subnet_ids doit contenir les clés \"web\" et \"db\"."
  }
}

variable "web_subnet_prefix" {
  description = "CIDR du sous-réseau web (seule source autorisée vers la base)"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Adresse IP (CIDR) autorisée à se connecter en SSH, ex : 88.12.34.56/32"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0)) && var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "allowed_ssh_cidr doit être un CIDR valide et ne doit pas ouvrir SSH à tout Internet (0.0.0.0/0)."
  }
}

variable "extra_nsg_rules" {
  description = "Règles NSG supplémentaires par rôle (web, db), ajoutées aux règles par défaut"
  type = map(list(object({
    name                   = string
    priority               = number
    access                 = string
    protocol               = string
    destination_port_range = string
    source_address_prefix  = string
  })))
  default = {}
}

variable "tags" {
  description = "Tags appliqués aux ressources"
  type        = map(string)
  default     = {}
}
