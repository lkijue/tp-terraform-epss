# Mesures de sécurité

## Secrets : aucun secret en clair

| Secret | Où il est stocké | Comment il est utilisé |
|---|---|---|
| Identifiants du Service Principal (`ARM_CLIENT_SECRET`) | HCP Terraform, variable set, **Sensitive** (chiffrée, non relisible) | Variable d'environnement des runs |
| Mot de passe PostgreSQL | Généré par `random_password`, stocké dans **Azure Key Vault** | Lu au démarrage par la VM db via son identité managée (aucun mot de passe dans cloud-init) |
| Clé privée SSH | Uniquement sur le poste de l'administrateur | Seule la clé **publique** est envoyée à Azure |
| State Terraform | HCP Terraform (chiffré au repos, verrouillage, historique) | Jamais dans Git (`.gitignore`) |

Le `.gitignore` exclut `*.tfstate`, `*.auto.tfvars`, `*.local.tfvars`, `secrets.tfvars`, clés SSH. Les `terraform.tfvars` versionnés ne contiennent que des valeurs non sensibles (région, CIDR, tailles).

## Identités et moindre privilège

- **Service Principal** `sp-cloudtech-terraform` : rôle `Contributor` limité à l'abonnement étudiant. Il ne peut pas attribuer de rôles ni gérer les accès.
- **Identité managée de la VM db** : uniquement `Get` sur les secrets du Key Vault de son environnement.
- **Access policy Terraform** : `Get, List, Set, Delete, Purge, Recover` sur les secrets, nécessaire pour créer et détruire le secret.

## Réseau

- Une seule IP publique (Load Balancer). Aucune VM exposée directement.
- SSH : uniquement depuis `allowed_ssh_cidr` (IP /32 de l'admin). Une **validation Terraform refuse `0.0.0.0/0`**.
- Base de données : joignable uniquement depuis `snet-web` (5432, 22), tout le reste refusé par une règle explicite `Deny-All-Other-Inbound`.
- Authentification SSH par clé uniquement (`disable_password_authentication = true`).

## Politiques Sentinel (HCP Terraform)

| Politique | Niveau | Effet |
|---|---|---|
| `restrict-vm-size-dev` | hard-mandatory | Refuse toute VM hors `Standard_B1s/B1ls/B1ms` dans le workspace dev |
| `allowed-locations` | hard-mandatory | Refuse tout déploiement hors des régions européennes autorisées |
| `require-tags` | advisory | Avertit si une ressource n'a pas les tags `project` et `environment` |

Les politiques sont testées en CI (`sentinel test`, 7 cas).

## Analyse statique (CI)

- **Trivy** bloque la CI sur toute vulnérabilité HIGH/CRITICAL.
- Exceptions assumées et justifiées dans `.trivyignore` :
  - `AZU-0047` : HTTP 80 ouvert sur Internet → c'est le site public ;
  - `AZU-0012` / `AZU-0013` : Storage et Key Vault joignables en réseau public (authentifié), car les runners HCP Terraform ont des IPs dynamiques ;
  - `AZU-0016` : purge protection désactivée pour permettre `terraform destroy` en contexte projet ;
  - `AZU-0068` : faux positif (NICs attachées via `count`).
- **TFLint** (ruleset azurerm) vérifie tailles de VM, conventions, variables inutilisées.

## Risques connus et améliorations possibles

| Risque / limite | Amélioration |
|---|---|
| Secret du Service Principal valable 1 an | Passer aux *dynamic provider credentials* (OIDC) de HCP Terraform : plus aucun secret |
| Key Vault et Storage en accès réseau public | Private Endpoints + agents HCP Terraform auto-hébergés dans le VNet |
| Mot de passe DB présent dans le state (chiffré) | Ressources `ephemeral` + attributs write-only (Terraform ≥ 1.11) |
| Purge protection désactivée | L'activer en vraie production |
| HTTP sans TLS | Application Gateway / certificat Let's Encrypt |
| SSH exposé via NAT | Azure Bastion (payant) |
