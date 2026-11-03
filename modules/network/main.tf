# -----------------------------------------------------------------------------
# Module network : un Virtual Network + N sous-réseaux créés dynamiquement.
# Les sous-réseaux sont décrits par une map (clé = rôle : "web", "db", ...),
# ce qui permet d'en ajouter un sans toucher au code du module.
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = "snet-${each.key}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value.address_prefix]
}
