<#
.SYNOPSIS
  Crée le Service Principal utilisé par HCP Terraform pour déployer sur Azure.
  Rôle "Contributor" limité à l'abonnement (principe du moindre privilège :
  il ne peut pas gérer les droits d'accès ni les autres abonnements).
.NOTES
  Le mot de passe (client secret) n'est affiché QU'UNE fois et n'est écrit
  dans aucun fichier : copie-le directement dans HCP Terraform (variable sensible).
  Le nom par défaut inclut l'identifiant de l'utilisateur : dans l'annuaire
  partagé d'une école, un nom fixe entre en collision avec celui d'un autre étudiant.
#>
param(
    [string]$Name
)

$ErrorActionPreference = "Stop"

$subscriptionId = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv
$me = az ad signed-in-user show --query userPrincipalName -o tsv

if (-not $Name) {
    $userPart = ($me.Split("@")[0] -replace "[^a-zA-Z0-9-]", "-").ToLower()
    $Name = "sp-cloudtech-terraform-$userPart"
}

# Une application du même nom appartenant à quelqu'un d'autre ne peut pas être réutilisée.
$existing = az ad app list --display-name $Name --query "[].id" -o tsv
foreach ($appObjectId in $existing) {
    $owners = az ad app owner list --id $appObjectId --query "[].userPrincipalName" -o tsv
    if ($owners -notcontains $me) {
        Write-Host "Le nom '$Name' est déjà pris dans l'annuaire par : $owners" -ForegroundColor Red
        Write-Host "Relance avec un autre nom : -Name sp-cloudtech-terraform-<autre-suffixe>" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Création du Service Principal '$Name' (rôle Contributor sur l'abonnement $subscriptionId)..." -ForegroundColor Cyan
$sp = az ad sp create-for-rbac `
    --name $Name `
    --role Contributor `
    --scopes "/subscriptions/$subscriptionId" `
    -o json | ConvertFrom-Json

if (-not $sp.appId) {
    Write-Host "Échec de la création. Voir la section 'Plan B' du guide." -ForegroundColor Red
    exit 1
}

Write-Host "`nÀ copier dans HCP Terraform > Variable set 'azure-credentials' (catégorie Environment variable) :`n" -ForegroundColor Green
[pscustomobject]@{ Cle = "ARM_CLIENT_ID";       Valeur = $sp.appId;        Sensible = "non" }
[pscustomobject]@{ Cle = "ARM_CLIENT_SECRET";   Valeur = $sp.password;     Sensible = "OUI (cocher Sensitive)" }
[pscustomobject]@{ Cle = "ARM_TENANT_ID";       Valeur = $tenantId;        Sensible = "non" }
[pscustomobject]@{ Cle = "ARM_SUBSCRIPTION_ID"; Valeur = $subscriptionId;  Sensible = "non" }
Write-Host "`nLe secret ne sera plus jamais affiché. Ferme ce terminal après l'avoir copié." -ForegroundColor Yellow
