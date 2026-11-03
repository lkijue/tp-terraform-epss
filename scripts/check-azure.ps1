<#
.SYNOPSIS
  Vérifie que l'abonnement Azure for Students peut accueillir le projet :
  régions autorisées, quotas de vCPU, disponibilité de la taille Standard_B1s.
.EXAMPLE
  .\scripts\check-azure.ps1 -Location francecentral
#>
param(
    [string]$Location = "francecentral",
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
az vm list-usage --location $Location `
    --query "[?contains(name.value,'cores') || contains(name.value,'BS')].{Quota:localName, Utilise:currentValue, Limite:limit}" -o table
Write-Host "Un environnement complet utilise 3 vCPU (3 x $VmSize)." -ForegroundColor Yellow

Write-Host "`n=== Disponibilité de $VmSize dans $Location ===" -ForegroundColor Cyan
$sku = az vm list-skus --location $Location --size $VmSize --resource-type virtualMachines -o json | ConvertFrom-Json
$exact = $sku | Where-Object { $_.name -eq $VmSize }
if (-not $exact) {
    Write-Host "ATTENTION : $VmSize n'existe pas dans $Location." -ForegroundColor Red
} elseif ($exact.restrictions.Count -gt 0) {
    Write-Host "ATTENTION : $VmSize est restreinte pour ton abonnement dans $Location :" -ForegroundColor Red
    $exact.restrictions | ForEach-Object { Write-Host "  - $($_.reasonCode)" }
} else {
    Write-Host "OK : $VmSize est disponible." -ForegroundColor Green
}
