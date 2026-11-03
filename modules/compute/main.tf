# -----------------------------------------------------------------------------
# Module compute :
#   - 1 Storage Account (diagnostics de démarrage des VMs)
#   - 1 IP publique + 1 Load Balancer Standard (HTTP + SSH par NAT + sortie Internet)
#   - N VMs web (count) derrière le Load Balancer, nginx installé par cloud-init
#   - 1 VM db (PostgreSQL) sans IP publique, mot de passe lu dans le Key Vault
# Aucune VM n'a d'IP publique : la seule IP publique est celle du Load Balancer.
# -----------------------------------------------------------------------------

locals {
  # Fonction ternaire : disques SSD en prod, HDD (moins cher) ailleurs.
  os_disk_type = var.environment == "prod" ? "StandardSSD_LRS" : "Standard_LRS"

  # Ports SSH exposés sur le Load Balancer : 2201 -> web-1, 2202 -> web-2...
  ssh_nat_base_port = 2200

  image = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

# --- Stockage des diagnostics -------------------------------------------------

resource "azurerm_storage_account" "diag" {
  # Nom global unique, minuscules et chiffres uniquement, 24 caractères max.
  name                            = substr(replace("st${var.short_name_prefix}", "-", ""), 0, 24)
  location                        = var.location
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  # Double chiffrement au repos (gratuit).
  infrastructure_encryption_enabled = true
  tags                              = var.tags
}

# --- Load Balancer ------------------------------------------------------------

resource "azurerm_public_ip" "lb" {
  name                = "pip-${var.name_prefix}-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.short_name_prefix
  tags                = var.tags
}

resource "azurerm_lb" "this" {
  name                = "lb-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

# Pool des serveurs web qui reçoivent le trafic HTTP.
resource "azurerm_lb_backend_address_pool" "web" {
  name            = "pool-web"
  loadbalancer_id = azurerm_lb.this.id
}

# Pool utilisé uniquement pour l'accès sortant (apt install...) de toutes les VMs.
resource "azurerm_lb_backend_address_pool" "outbound" {
  name            = "pool-outbound"
  loadbalancer_id = azurerm_lb.this.id
}

resource "azurerm_lb_probe" "http" {
  name                = "probe-http"
  loadbalancer_id     = azurerm_lb.this.id
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http" {
  name                           = "rule-http"
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id
  # La sortie Internet est gérée par la règle "outbound" ci-dessous.
  disable_outbound_snat = true
}

resource "azurerm_lb_outbound_rule" "internet" {
  name                     = "outbound-internet"
  loadbalancer_id          = azurerm_lb.this.id
  protocol                 = "All"
  backend_address_pool_id  = azurerm_lb_backend_address_pool.outbound.id
  allocated_outbound_ports = 1024

  frontend_ip_configuration {
    name = "public"
  }
}

resource "azurerm_lb_nat_rule" "ssh_web" {
  count = var.web_vm_count

  name                           = "nat-ssh-web-${count.index + 1}"
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = local.ssh_nat_base_port + count.index + 1
  backend_port                   = 22
  frontend_ip_configuration_name = "public"
}

# --- VMs web --------------------------------------------------------------------

resource "azurerm_network_interface" "web" {
  count = var.web_vm_count

  name                = "nic-${var.name_prefix}-web-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.web_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  count = var.web_vm_count

  network_interface_id    = azurerm_network_interface.web[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web.id
}

resource "azurerm_network_interface_backend_address_pool_association" "web_outbound" {
  count = var.web_vm_count

  network_interface_id    = azurerm_network_interface.web[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.outbound.id
}

resource "azurerm_network_interface_nat_rule_association" "ssh_web" {
  count = var.web_vm_count

  network_interface_id  = azurerm_network_interface.web[count.index].id
  ip_configuration_name = "internal"
  nat_rule_id           = azurerm_lb_nat_rule.ssh_web[count.index].id
}

resource "azurerm_linux_virtual_machine" "web" {
  count = var.web_vm_count

  name                  = "vm-${var.name_prefix}-web-${count.index + 1}"
  computer_name         = "web-${count.index + 1}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.web_vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.web[count.index].id]
  tags                  = merge(var.tags, { role = "web" })

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = local.os_disk_type
  }

  source_image_reference {
    publisher = local.image.publisher
    offer     = local.image.offer
    sku       = local.image.sku
    version   = local.image.version
  }

  custom_data = base64encode(templatefile("${path.module}/templates/web-cloud-init.yaml.tftpl", {
    environment = var.environment
    project     = var.project
  }))

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diag.primary_blob_endpoint
  }

  # Le pool sortant doit exister avant le démarrage, sinon "apt install nginx" échoue.
  depends_on = [
    azurerm_network_interface_backend_address_pool_association.web_outbound,
    azurerm_lb_outbound_rule.internet,
  ]
}

# --- VM db ----------------------------------------------------------------------

resource "azurerm_network_interface" "db" {
  name                = "nic-${var.name_prefix}-db"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.db_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "db_outbound" {
  network_interface_id    = azurerm_network_interface.db.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.outbound.id
}

resource "azurerm_linux_virtual_machine" "db" {
  name                  = "vm-${var.name_prefix}-db"
  computer_name         = "db"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.db_vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.db.id]
  tags                  = merge(var.tags, { role = "db" })

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.db_identity_id]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = local.os_disk_type
  }

  source_image_reference {
    publisher = local.image.publisher
    offer     = local.image.offer
    sku       = local.image.sku
    version   = local.image.version
  }

  # Le cloud-init ne contient AUCUN secret : seulement le nom du Key Vault
  # et l'identité à utiliser pour aller y lire le mot de passe.
  custom_data = base64encode(templatefile("${path.module}/templates/db-cloud-init.yaml.tftpl", {
    key_vault_name     = var.key_vault_name
    secret_name        = var.db_password_secret_name
    identity_client_id = var.db_identity_client_id
    web_subnet_prefix  = var.web_subnet_prefix
  }))

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diag.primary_blob_endpoint
  }

  depends_on = [
    azurerm_network_interface_backend_address_pool_association.db_outbound,
    azurerm_lb_outbound_rule.internet,
  ]
}

# --- Monitoring (bonus, activé seulement si un e-mail est fourni) ---------------

resource "azurerm_monitor_action_group" "this" {
  count = var.alert_email != "" ? 1 : 0

  name                = "ag-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  short_name          = substr(replace(var.name_prefix, "-", ""), 0, 12)
  tags                = var.tags

  email_receiver {
    name          = "admin"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_metric_alert" "web_cpu" {
  count = var.alert_email != "" ? 1 : 0

  name                     = "alert-${var.name_prefix}-web-cpu"
  resource_group_name      = var.resource_group_name
  scopes                   = azurerm_linux_virtual_machine.web[*].id
  description              = "CPU moyen > 80 % sur un serveur web"
  severity                 = 2
  target_resource_type     = "Microsoft.Compute/virtualMachines"
  target_resource_location = var.location
  tags                     = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.this[0].id
  }
}
