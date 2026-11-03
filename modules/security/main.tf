# -----------------------------------------------------------------------------
# Module security :
#   - 2 Network Security Groups (web + db) dont les règles sont générées
#     avec des blocs "dynamic" à partir d'une liste de règles ;
#   - un Azure Key Vault qui stocke le mot de passe PostgreSQL (généré
#     aléatoirement, jamais écrit dans le code ni dans Git) ;
#   - l'identité managée de la VM db, autorisée à lire ce secret.
# -----------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

locals {
  # Règles par défaut. Chaque environnement peut en ajouter via var.extra_nsg_rules.
  default_nsg_rules = {
    web = [
      {
        name                   = "Allow-HTTP-Internet"
        priority               = 100
        access                 = "Allow"
        protocol               = "Tcp"
        destination_port_range = "80"
        source_address_prefix  = "Internet"
      },
      {
        name                   = "Allow-SSH-Admin"
        priority               = 110
        access                 = "Allow"
        protocol               = "Tcp"
        destination_port_range = "22"
        source_address_prefix  = var.allowed_ssh_cidr
      },
    ]
    db = [
      {
        name                   = "Allow-PostgreSQL-From-Web"
        priority               = 100
        access                 = "Allow"
        protocol               = "Tcp"
        destination_port_range = "5432"
        source_address_prefix  = var.web_subnet_prefix
      },
      {
        name                   = "Allow-SSH-From-Web"
        priority               = 110
        access                 = "Allow"
        protocol               = "Tcp"
        destination_port_range = "22"
        source_address_prefix  = var.web_subnet_prefix
      },
      {
        # La base n'est joignable que depuis le sous-réseau web.
        name                   = "Deny-All-Other-Inbound"
        priority               = 4000
        access                 = "Deny"
        protocol               = "*"
        destination_port_range = "*"
        source_address_prefix  = "*"
      },
    ]
  }

  nsg_rules = {
    for role, rules in local.default_nsg_rules :
    role => concat(rules, lookup(var.extra_nsg_rules, role, []))
  }
}

resource "azurerm_network_security_group" "this" {
  for_each = local.nsg_rules

  name                = "nsg-${var.name_prefix}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Bloc dynamique : une règle "security_rule" par élément de la liste.
  dynamic "security_rule" {
    for_each = each.value
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.nsg_rules

  subnet_id                 = var.subnet_ids[each.key]
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# --- Gestion des secrets -----------------------------------------------------

resource "azurerm_user_assigned_identity" "db" {
  name                = "id-${var.name_prefix}-db"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_key_vault" "this" {
  name                       = "kv-${var.short_name_prefix}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  # Désactivé volontairement pour pouvoir faire "terraform destroy" proprement
  # dans un contexte de projet étudiant (à activer en vraie production).
  purge_protection_enabled = false
  tags                     = var.tags

  # Accès réseau ouvert mais authentifié : les runners HCP Terraform (IPs
  # dynamiques) et la VM db doivent joindre le coffre. Chaque accès reste
  # soumis aux access policies ci-dessous.
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

# Droits de l'identité qui exécute Terraform (service principal ou compte az login).
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

# La VM db peut uniquement LIRE les secrets.
resource "azurerm_key_vault_access_policy" "db_identity" {
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.db.principal_id

  secret_permissions = ["Get"]
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-app-password"
  value        = random_password.db.result
  key_vault_id = azurerm_key_vault.this.id
  content_type = "password"
  tags         = var.tags

  depends_on = [azurerm_key_vault_access_policy.terraform]
}
