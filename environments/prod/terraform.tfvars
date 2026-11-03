# Valeurs NON sensibles de l'environnement prod (versionnées dans Git).
# ssh_public_key et allowed_ssh_cidr sont fournies par HCP Terraform.
# En prod, les disques passent automatiquement en SSD (fonction ternaire du module compute).

environment = "prod"
location    = "denmarkeast"

address_space = ["10.30.0.0/16"]
subnets = {
  web = { address_prefix = "10.30.1.0/24" }
  db  = { address_prefix = "10.30.2.0/24" }
}

web_vm_count = 2
web_vm_size  = "Standard_B1s"
db_vm_size   = "Standard_B1s"
