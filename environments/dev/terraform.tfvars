# Valeurs NON sensibles de l'environnement dev (versionnées dans Git).
# ssh_public_key et allowed_ssh_cidr sont fournies par HCP Terraform.

environment = "dev"
location    = "denmarkeast"

address_space = ["10.10.0.0/16"]
subnets = {
  web = { address_prefix = "10.10.1.0/24" }
  db  = { address_prefix = "10.10.2.0/24" }
}

web_vm_count = 2
web_vm_size  = "Standard_B1s"
db_vm_size   = "Standard_B1s"
