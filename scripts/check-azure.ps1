<#
.SYNOPSIS
  Vérifie que l'abonnement Azure for Students peut accueillir le projet :
  régions autorisées, quotas de vCPU, disponibilité de la taille Standard_B1s.
.EXAMPLE
  .\scripts\check-azure.ps1 -Location denmarkeast
#>
param(
    [string]$Location = "denmarkeast",
    [string]$VmSize = "Standard_B1s"
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Abonnement actif ===" -ForegroundColor Cyan
az account show --query "{Nom:name, Id:id, Tenant:tenantId, Etat:state}" -o table

Write-Host "`n=== Régions autorisées par la politique de l'abonnement ===" -ForegroundColor Cyan
$assignments = az policy assignment list --query "[].{name:displayName, params:parameters}" -o json | ConvertFrom-Json
$regionPolicy = $assignments | Where-Object { $_.params.listOfAllowedLocations }
if ($regionPolicy) {
    $allowed = $regionPolicy[0].params.listOfAllowedLocations.value
    $allowed | ForEach-Object { Write-Host "  - $_" }
    if ($allowed -contains $Location) {
        Write-Host "OK : $Location est autorisée." -ForegroundColor Green
    } else {
        Write-Host "ATTENTION : $Location n'est PAS autorisée. Choisis une région de la liste ci-dessus" -ForegroundColor Red
        Write-Host "et mets-la dans environments/*/terraform.tfvars (variable location)." -ForegroundColor Red
    }
} else {
    Write-Host "Aucune restriction de région trouvée." -ForegroundColor Yellow
}

Write-Host "`n=== Quotas vCPU dans $Location ===" -ForegroundColor Cyan
$usage = az vm list-usage --location $Location -o json | ConvertFrom-Json
$quotas = $usage | Where-Object { $_.localName -match "Total Regional|Standard BS" }
if ($quotas) {
    $quotas | ForEach-Object { Write-Host ("  {0,-38} {1} utilisés / {2}" -f $_.localName, $_.currentValue, $_.limit) }
} else {
    # Abonnement neuf : le service Compute n'est pas encore enregistré.
    Write-Host "Quotas illisibles : lance 'az provider register --namespace Microsoft.Compute', attends 2 minutes et relance le script." -ForegroundColor Yellow
}
Write-Host "Un environnement complet utilise 3 vCPU (3 x $VmSize)." -ForegroundColor Yellow

Write-Host "`n=== Disponibilité de $VmSize dans $Location ===" -ForegroundColor Cyan
# --all : sans ce flag, Azure masque les tailles bloquées pour l'abonnement.
$sku = az vm list-skus --location $Location --size $VmSize --resource-type virtualMachines --all -o json | ConvertFrom-Json
$exact = $sku | Where-Object { $_.name -eq $VmSize }
# Une restriction de type "Zone" n'empêche pas de déployer sans zone (cas de ce projet).
$blocking = $exact.restrictions | Where-Object { $_.type -eq "Location" }
if (-not $exact) {
    Write-Host "ATTENTION : $VmSize n'existe pas dans $Location." -ForegroundColor Red
} elseif ($blocking) {
    Write-Host "ATTENTION : $VmSize est bloquée pour ton abonnement dans $Location ($($blocking[0].reasonCode))." -ForegroundColor Red
    Write-Host "Essaie une autre région autorisée de la liste ci-dessus." -ForegroundColor Red
} else {
    Write-Host "OK : $VmSize est disponible." -ForegroundColor Green
}
