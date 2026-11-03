# CloudTech Solutions – Infrastructure Azure multi-environnement (Terraform)

Déploiement automatisé, avec Terraform et HCP Terraform, d'une infrastructure web sur Azure en trois environnements identiques : **dev**, **staging**, **prod**.

```
Internet ──HTTP:80──► IP publique ─► Load Balancer ─┬─► VM web-1 (nginx) ─┐
Admin ───SSH:2201/2202──────────────────────────────┴─► VM web-2 (nginx) ─┴─5432─► VM db (PostgreSQL) ──► Key Vault
```

Par environnement : 1 Resource Group, 1 VNet + 2 subnets, 2 NSG, 1 IP publique, 1 Load Balancer, 3 VMs Linux (2 web + 1 db), 1 Storage Account (diagnostics), 1 Key Vault.
Détails et diagrammes : [docs/architecture.md](docs/architecture.md).

## Structure

```
terraform-azure-project/
├── README.md
├── .github/workflows/terraform-ci.yml   # CI : fmt, validate, tests, TFLint, Trivy, Sentinel
├── .gitignore / .trivyignore / .tflint.hcl
├── environments/
│   ├── dev/        # main.tf, variables.tf, outputs.tf, versions.tf, terraform.tfvars, tests/
│   ├── staging/
│   └── prod/
├── modules/
│   ├── network/    # VNet + subnets dynamiques (for_each) → IDs des subnets ; tests/
│   ├── security/   # NSG (blocs dynamic) + Key Vault + identité managée
│   └── compute/    # Load Balancer, VMs web (count), VM db, storage diagnostics
├── policies/       # Politiques Sentinel + tests
├── scripts/        # check-azure.ps1, create-service-principal.ps1
├── tests/          # smoke-test.ps1 (tests post-déploiement)
└── docs/           # architecture.md, deployment.md, security.md, fiche-mission.md
```

## Concepts Terraform utilisés

| Concept | Où |
|---|---|
| Modules réutilisables | `modules/network`, `modules/security`, `modules/compute` |
| `for_each` sur une map | Sous-réseaux, NSG, associations NSG ↔ subnet |
| Blocs `dynamic` | Règles `security_rule` des NSG |
| `count` | VMs web, NICs, règles NAT, monitoring optionnel |
| Fonctions ternaires | Type de disque (`prod ? SSD : HDD`), monitoring (`alert_email != "" ? 1 : 0`) |
| Validations de variables | CIDR valides, SSH jamais ouvert à `0.0.0.0/0`, environnement connu, clé SSH |
| Variables + `terraform.tfvars` | Une configuration par environnement |
| Outputs | IDs des subnets, IP du LB, commandes SSH... |
| State distant | HCP Terraform (un workspace par environnement) |
| Tests | `terraform test` avec `mock_provider` (sans Azure) |

## Démarrage rapide

```powershell
az login
powershell -ExecutionPolicy Bypass -File .\scripts\check-azure.ps1 -Location francecentral
```

Puis suivre [docs/deployment.md](docs/deployment.md). Les runs (plan / apply / destroy) sont exécutés par HCP Terraform, déclenchés par Git :

| Branche | Workspace HCP Terraform |
|---|---|
| `develop` | `cloudtech-dev` |
| `main` | `cloudtech-staging`, `cloudtech-prod` |

## Tests

```powershell
terraform -chdir=modules/network init;  terraform -chdir=modules/network test      # module réseau
terraform -chdir=environments/dev init -backend=false; terraform -chdir=environments/dev test   # environnement complet (mock)
cd policies; sentinel test                                                          # politiques Sentinel
powershell -ExecutionPolicy Bypass -File .\tests\smoke-test.ps1 -Environment dev   # après déploiement réel
```

## Coûts

Taille `Standard_B1s` partout. Un environnement coûte environ 1,5 $/jour s'il reste allumé : **détruire après chaque session de tests**. Un seul environnement à la fois (quota étudiant de vCPU).

## Sécurité

Aucun secret dans Git : identifiants Azure en variables sensibles HCP Terraform, mot de passe PostgreSQL dans Key Vault, SSH par clé et limité à une IP. Voir [docs/security.md](docs/security.md).
