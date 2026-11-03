# -----------------------------------------------------------------------------
# Environnement : assemble les modules network, security et compute.
# Ce fichier est identique dans dev / staging / prod : seules les valeurs
# de terraform.tfvars (et le workspace HCP Terraform) changent.
# -----------------------------------------------------------------------------

locals {
  env_short   = { dev = "dev", staging = "stg", prod = "prd" }[var.environment]
  name_prefix = "${var.project}-${var.environment}"
  # Suffixe aléatoire pour les noms qui doivent être uniques dans tout Azure.
  short_name_prefix = "${var.project}-${local.env_short}-${random_string.suffix.result}"

  tags = merge(var.extra_tags, {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  })
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../../modules/network"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.address_space
  subnets             = var.subnets
  tags                = local.tags
}

module "security" {
  source = "../../modules/security"

  name_prefix         = local.name_prefix
  short_name_prefix   = local.short_name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_ids          = module.network.subnet_ids
  web_subnet_prefix   = module.network.subnet_address_prefixes["web"]
  allowed_ssh_cidr    = var.allowed_ssh_cidr
  extra_nsg_rules     = var.extra_nsg_rules
  tags                = local.tags
}

module "compute" {
  source = "../../modules/compute"

  project             = var.project
  environment         = var.environment
  name_prefix         = local.name_prefix
  short_name_prefix   = local.short_name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  # Les deux types de VMs sont placés dans deux sous-réseaux différents.
  web_subnet_id     = module.network.subnet_ids["web"]
  web_subnet_prefix = module.network.subnet_address_prefixes["web"]
  db_subnet_id      = module.network.subnet_ids["db"]

  web_vm_count   = var.web_vm_count
  web_vm_size    = var.web_vm_size
  db_vm_size     = var.db_vm_size
  admin_username = var.admin_username
  ssh_public_key = var.ssh_public_key

  db_identity_id          = module.security.db_identity_id
  db_identity_client_id   = module.security.db_identity_client_id
  key_vault_name          = module.security.key_vault_name
  db_password_secret_name = module.security.db_password_secret_name

  alert_email = var.alert_email
  tags        = local.tags

  # Les NSG doivent être associés aux sous-réseaux avant de créer les VMs.
  depends_on = [module.security]
}
