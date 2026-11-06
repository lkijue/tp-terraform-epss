# Test d'intégration "à blanc" d'un environnement complet : le provider Azure
# est simulé (mock), donc rien n'est créé ni facturé. Vérifie le câblage des
# modules, les templates cloud-init, les règles NSG et les validations.
# Lancement : terraform -chdir=environments/dev test

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000001"
      object_id = "00000000-0000-0000-0000-000000000002"
    }
  }

  # Le provider vérifie le format des IDs : on fournit des IDs au format Azure.
  mock_resource "azurerm_subnet" {
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet"
      address_prefixes = ["10.10.1.0/24"]
    }
  }

  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg"
    }
  }

  mock_resource "azurerm_key_vault" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.KeyVault/vaults/kv"
    }
  }

  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id"
      principal_id = "00000000-0000-0000-0000-000000000003"
      client_id    = "00000000-0000-0000-0000-000000000004"
    }
  }

  mock_resource "azurerm_public_ip" {
    defaults = {
      id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/publicIPAddresses/pip"
      ip_address = "20.0.0.1"
      fqdn       = "cloudtech-dev-test.francecentral.cloudapp.azure.com"
    }
  }

  mock_resource "azurerm_lb" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/loadBalancers/lb"
    }
  }

  mock_resource "azurerm_lb_backend_address_pool" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/loadBalancers/lb/backendAddressPools/pool"
    }
  }

  mock_resource "azurerm_lb_probe" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/loadBalancers/lb/probes/probe"
    }
  }

  mock_resource "azurerm_lb_nat_rule" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/loadBalancers/lb/inboundNatRules/nat"
    }
  }

  mock_resource "azurerm_network_interface" {
    defaults = {
      id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/networkInterfaces/nic"
      private_ip_address = "10.10.1.4"
    }
  }

  mock_resource "azurerm_storage_account" {
    defaults = {
      id                    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/st"
      primary_blob_endpoint = "https://st.blob.core.windows.net/"
    }
  }

  mock_resource "azurerm_linux_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm"
    }
  }
}

variables {
  ssh_public_key   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBzWw7yqfJ2xFv0iEJk6Xr5fYyQKk2gyF6Yb0XbX6Xm0 test"
  allowed_ssh_cidr = "203.0.113.10/32"
}

run "environnement_dev_complet" {
  command = apply

  assert {
    condition     = azurerm_resource_group.this.name == "rg-cloudtech-dev"
    error_message = "Nom du Resource Group inattendu."
  }

  # Le nombre attendu suit terraform.tfvars : changer web_vm_count ne casse pas le test.
  assert {
    condition     = length(module.compute.web_vm_names) == var.web_vm_count
    error_message = "Il doit y avoir autant de VMs web que web_vm_count."
  }

  assert {
    condition     = length(output.ssh_commands) == var.web_vm_count
    error_message = "Il doit y avoir une commande SSH par VM web."
  }

  assert {
    condition     = output.ssh_commands[0] == "ssh -p 2201 azureuser@20.0.0.1"
    error_message = "La VM web-1 doit être joignable en SSH sur le port 2201 du Load Balancer."
  }

  assert {
    condition     = length(module.security.key_vault_name) <= 24
    error_message = "Le nom du Key Vault dépasse 24 caractères."
  }

  assert {
    condition     = length(module.compute.storage_account_name) <= 24
    error_message = "Le nom du Storage Account dépasse 24 caractères."
  }
}

run "refuse_ssh_ouvert_a_tout_internet" {
  command = plan

  variables {
    allowed_ssh_cidr = "0.0.0.0/0"
  }

  expect_failures = [var.allowed_ssh_cidr]
}

run "refuse_un_environnement_inconnu" {
  command = plan

  variables {
    environment = "test"
  }

  expect_failures = [var.environment]
}
