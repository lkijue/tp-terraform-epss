variable "project" {
  description = "Nom court du projet (minuscules, sans espace)"
  type        = string
  default     = "cloudtech"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,9}$", var.project))
    error_message = "project : 3 à 10 caractères, minuscules et chiffres, commence par une lettre."
  }
}

variable "environment" {
  description = "Nom de l'environnement"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment doit valoir dev, staging ou prod."
  }
}

variable "location" {
  description = "Région Azure (doit être autorisée par la politique de l'abonnement étudiant)"
  type        = string
}

variable "address_space" {
  description = "Plage d'adresses du VNet"
  type        = list(string)
}

variable "subnets" {
  description = "Sous-réseaux à créer (doit contenir web et db)"
  type = map(object({
    address_prefix = string
  }))
}

variable "web_vm_count" {
  description = "Nombre de VMs web"
  type        = number
  default     = 2
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

# --- Valeurs fournies par HCP Terraform (variable set), jamais dans Git -------

variable "ssh_public_key" {
  description = "Clé publique SSH (contenu de ~/.ssh/id_ed25519.pub)"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Ton IP publique en /32, seule autorisée en SSH"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0)) && var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "allowed_ssh_cidr doit être un CIDR valide (ex : 88.12.34.56/32), jamais 0.0.0.0/0."
  }
}

variable "alert_email" {
  description = "E-mail des alertes CPU (vide = monitoring désactivé)"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------

variable "extra_nsg_rules" {
  description = "Règles NSG supplémentaires par rôle (web, db)"
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

variable "extra_tags" {
  description = "Tags supplémentaires"
  type        = map(string)
  default     = {}
}
