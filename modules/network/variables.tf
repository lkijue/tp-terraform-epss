variable "name_prefix" {
  description = "Préfixe de nommage, ex : cloudtech-dev"
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

variable "address_space" {
  description = "Plage(s) d'adresses du VNet, ex : [\"10.10.0.0/16\"]"
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.address_space : can(cidrhost(cidr, 0))])
    error_message = "Chaque élément de address_space doit être un CIDR valide (ex : 10.10.0.0/16)."
  }
}

variable "subnets" {
  description = "Sous-réseaux à créer. Clé = rôle (web, db...), valeur = CIDR du sous-réseau."
  type = map(object({
    address_prefix = string
  }))

  validation {
    condition     = length(var.subnets) > 0
    error_message = "Il faut au moins un sous-réseau."
  }

  validation {
    condition     = alltrue([for s in values(var.subnets) : can(cidrhost(s.address_prefix, 0))])
    error_message = "Chaque address_prefix doit être un CIDR valide (ex : 10.10.1.0/24)."
  }
}

variable "tags" {
  description = "Tags appliqués aux ressources"
  type        = map(string)
  default     = {}
}
