# Fiche de mission

**Apprenant :** Enzo Pereira
**Projet :** Déploiement d'une infrastructure multi-environnement sur Azure avec Terraform (CloudTech Solutions)
**Rôle / tâche individuelle :** _à compléter (ex : module réseau + sécurité, CI/CD, Sentinel, Key Vault...)_

## Objectifs

- Déployer une infrastructure web 3-tiers (LB, 2 VMs web, 1 VM db) sur Azure, à l'identique en dev, staging et prod.
- Rendre le code réutilisable : modules `network`, `security`, `compute` paramétrés par variables et `terraform.tfvars`.
- Optimiser le code : blocs `dynamic` (règles NSG), `for_each` (sous-réseaux), `count` (VMs web, monitoring), fonctions ternaires.
- Sécuriser : state distant dans HCP Terraform, Service Principal à moindre privilège, aucun secret en clair (Key Vault), NSG restrictifs, politiques Sentinel.
- Automatiser : pipeline CI GitHub Actions (fmt, validate, tests, TFLint, Trivy, Sentinel) + runs HCP Terraform liés aux branches Git.

## Livrables

- Dépôt Git structuré (`environments/`, `modules/`, `policies/`, `scripts/`, `tests/`, `docs/`).
- Documentation : README, DAT avec diagrammes (`docs/architecture.md`), procédures (`docs/deployment.md`), sécurité (`docs/security.md`).
- Infrastructure dev déployée et testée (captures : plan, apply, site via LB, SSH, topologie Network Watcher), puis détruite.
- Tests automatisés : `terraform test` (mock), `sentinel test`, `tests/smoke-test.ps1`.

## Difficultés anticipées

| Difficulté | Parade prévue |
|---|---|
| Quota de 4-6 vCPU de l'offre étudiante | Un environnement déployé à la fois, VMs B1s (1 vCPU) |
| Régions limitées par la politique de l'abonnement | Vérification préalable (`scripts/check-azure.ps1`) + politique Sentinel |
| Crédit de 100 $ | Destruction systématique après les tests, pas de NAT Gateway ni Bastion |
| Droits limités dans le tenant de l'école (Service Principal) | Plan B : exécution locale avec `az login`, state toujours dans HCP Terraform |
| VMs sans IP publique mais besoin d'Internet (apt) | Outbound rule sur le Load Balancer Standard |
| Secret DB sans le stocker en clair | Key Vault + identité managée lue au boot |
| Noms globaux uniques (Storage, Key Vault, DNS) | Suffixe `random_string` |

## Suivi

| Date | Avancement |
|---|---|
| | |
