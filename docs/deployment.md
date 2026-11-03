# Procédures de déploiement

## Prérequis (une seule fois)

1. Outils : `terraform` ≥ 1.9, `az` (Azure CLI), `git`.
2. `az login` puis `.\scripts\check-azure.ps1 -Location <région>` : région autorisée, quotas, taille B1s disponible.
3. Clé SSH : `ssh-keygen -t ed25519`.
4. Service Principal : `.\scripts\create-service-principal.ps1`.
5. HCP Terraform : organisation, variable set `azure-credentials` (ARM_* + `ssh_public_key` + `allowed_ssh_cidr`), 3 workspaces VCS (`cloudtech-dev` → branche `develop`, `cloudtech-staging` et `cloudtech-prod` → branche `main`), policy set `policies/`.

## Déployer un environnement

| Étape | Action |
|---|---|
| Plan | Push sur la branche suivie (ou bouton **New run** dans le workspace) |
| Vérification | Lire le plan + résultat des politiques Sentinel |
| Apply | Bouton **Confirm & apply** (jamais automatique) |
| Résultat | Onglet **Outputs** du workspace : `website_url`, `ssh_commands`... |

Contrainte de quota étudiant : déployer **un environnement à la fois** (3 vCPU par environnement).

## Vérifier

```powershell
terraform login
terraform -chdir=environments/dev init
terraform -chdir=environments/dev state list
terraform -chdir=environments/dev state show 'module.compute.azurerm_linux_virtual_machine.web[0]'
az vm list --resource-group rg-cloudtech-dev --output table
az network lb list --resource-group rg-cloudtech-dev --output table
powershell -ExecutionPolicy Bypass -File .\tests\smoke-test.ps1 -Environment dev
```

- SSH vers web-1 : `ssh -p 2201 azureuser@<IP_LB>`
- SSH vers la db (rebond par web-1) : output `ssh_db_command`
- Topologie : Portail Azure → Network Watcher → Topologie → Resource Group `rg-cloudtech-dev`

## Détruire

HCP Terraform → workspace → **Settings → Destruction and Deletion → Queue destroy plan** → **Confirm & apply**.
Vérifier ensuite : `az group list --output table` ne doit plus afficher `rg-cloudtech-<env>`.

## Promotion dev → staging → prod

1. Feature branch → PR vers `develop` → CI verte → merge → apply sur dev → tests.
2. PR `develop` → `main` → CI verte → merge → apply staging → tests → apply prod.

## Dépannage

| Erreur | Cause | Solution |
|---|---|---|
| `RequestDisallowedByPolicy` | Région interdite par l'abonnement étudiant | Changer `location` dans les `terraform.tfvars` |
| `QuotaExceeded` / `OperationNotAllowed ... cores` | Quota de vCPU atteint | Détruire l'autre environnement avant |
| `SkuNotAvailable` | B1s indisponible dans la région | Autre région, ou `Standard_B2ats_v2` (penser à la politique Sentinel dev) |
| `Insufficient privileges` à la création du SP | Le tenant de l'école bloque les app registrations | Plan B du guide : exécution locale avec `az login` |
| `VaultAlreadyExists` / nom déjà pris | Key Vault supprimé encore en soft-delete | `az keyvault purge --name <nom>` ou attendre 7 jours |
| Site inaccessible juste après l'apply | cloud-init installe encore nginx | Attendre 2-3 minutes |
