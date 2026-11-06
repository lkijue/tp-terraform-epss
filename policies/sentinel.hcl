# Policy set HCP Terraform (Sentinel), appliqué aux 3 workspaces.
# Les politiques sont évaluées après chaque "plan", avant "apply".

policy "restrict-vm-size-dev" {
  source            = "./restrict-vm-size-dev.sentinel"
  enforcement_level = "hard-mandatory"
}

# Advisory : le plan gratuit n'autorise qu'une politique bloquante, et les régions
# sont déjà bloquées par la politique Azure de l'abonnement (voir docs/security.md).
policy "allowed-locations" {
  source            = "./allowed-locations.sentinel"
  enforcement_level = "advisory"
}

policy "require-tags" {
  source            = "./require-tags.sentinel"
  enforcement_level = "advisory"
}
