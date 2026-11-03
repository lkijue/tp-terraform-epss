# Tests unitaires du module network (aucune ressource réelle créée).
# Lancement : terraform -chdir=modules/network test

mock_provider "azurerm" {}

variables {
  name_prefix         = "test-dev"
  location            = "francecentral"
  resource_group_name = "rg-test-dev"
  address_space       = ["10.99.0.0/16"]
  subnets = {
    web = { address_prefix = "10.99.1.0/24" }
    db  = { address_prefix = "10.99.2.0/24" }
  }
}

run "cree_un_subnet_par_entree" {
  command = apply

  assert {
    condition     = length(azurerm_subnet.this) == 2
    error_message = "Le module doit créer exactement 2 sous-réseaux."
  }

  assert {
    condition     = azurerm_subnet.this["web"].name == "snet-web"
    error_message = "Le sous-réseau web doit s'appeler snet-web."
  }

  assert {
    condition     = output.subnet_address_prefixes["db"] == "10.99.2.0/24"
    error_message = "Le CIDR du sous-réseau db est incorrect."
  }

  assert {
    condition     = toset(keys(output.subnet_ids)) == toset(["web", "db"])
    error_message = "L'output subnet_ids doit être indexé par rôle."
  }
}

run "ajout_dynamique_d_un_subnet" {
  command = plan

  variables {
    subnets = {
      web   = { address_prefix = "10.99.1.0/24" }
      db    = { address_prefix = "10.99.2.0/24" }
      admin = { address_prefix = "10.99.3.0/24" }
    }
  }

  assert {
    condition     = length(azurerm_subnet.this) == 3
    error_message = "Ajouter une entrée dans la map doit créer un sous-réseau de plus."
  }
}

run "refuse_un_cidr_invalide" {
  command = plan

  variables {
    subnets = {
      web = { address_prefix = "pas-un-cidr" }
    }
  }

  expect_failures = [var.subnets]
}
