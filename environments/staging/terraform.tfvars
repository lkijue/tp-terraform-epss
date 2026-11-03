# Valeurs NON sensibles de l'environnement staging (versionnées dans Git).
# ssh_public_key et allowed_ssh_cidr sont fournies par HCP Terraform.

environment = "staging"
location    = "denmarkeast"

address_space = ["10.20.0.0/16"]
subnets = {
  web = { address_prefix = "10.20.1.0/24" }
  db  = { address_prefix = "10.20.2.0/24" }
}

web_vm_count = 2
web_vm_size  = "Standard_B1s"
db_vm_size   = "Standard_B1s"
