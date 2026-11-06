<#
.SYNOPSIS
  Tests post-déploiement d'un environnement réellement déployé sur Azure :
    1. state Terraform lisible et complet
    2. ressources visibles via Azure CLI
    3. site joignable via le Load Balancer et répartition sur les 2 VMs web
    4. port SSH ouvert sur le NAT du Load Balancer
.EXAMPLE
  .\tests\smoke-test.ps1 -Environment dev
#>
param(
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$envDir = Join-Path $root "environments/$Environment"
$failures = 0

function Test-Step([string]$Name, [scriptblock]$Check) {
    try {
        $result = & $Check
        if ($result) { Write-Host "[OK]    $Name" -ForegroundColor Green }
        else { Write-Host "[ECHEC] $Name" -ForegroundColor Red; $script:failures++ }
    } catch {
        Write-Host "[ECHEC] $Name : $_" -ForegroundColor Red; $script:failures++
    }
}

$out = terraform -chdir="$envDir" output -json | ConvertFrom-Json
$rg = $out.resource_group_name.value
$ip = $out.lb_public_ip.value
# VMs web (autant que web_vm_count) + la VM db.
$expectedVms = @($out.web_private_ips.value).Count + 1

Write-Host "`n=== 1. State Terraform ($Environment) ===" -ForegroundColor Cyan
$state = terraform -chdir="$envDir" state list
$state | ForEach-Object { Write-Host "  $_" }
Test-Step "$expectedVms VMs dans le state" { ($state | Where-Object { $_ -like "*azurerm_linux_virtual_machine*" }).Count -eq $expectedVms }
Test-Step "Load Balancer dans le state" { $state -contains "module.compute.azurerm_lb.this" }
Test-Step "2 NSG dans le state" { ($state | Where-Object { $_ -like "*azurerm_network_security_group.this*" }).Count -eq 2 }

Write-Host "`n=== 2. Vérification via Azure CLI ($rg) ===" -ForegroundColor Cyan
az vm list --resource-group $rg --show-details --query "[].{VM:name, Etat:powerState, IP_privee:privateIps}" -o table
az network lb list --resource-group $rg --query "[].{LB:name, SKU:sku.name}" -o table
Test-Step "$expectedVms VMs en cours d'exécution" {
    (az vm list --resource-group $rg --show-details --query "[?powerState=='VM running'] | length(@)" -o tsv) -eq "$expectedVms"
}

Write-Host "`n=== 3. Load Balancer : http://$ip ===" -ForegroundColor Cyan
$servers = @{}
$webCount = $expectedVms - 1
1..(6 * $webCount) | ForEach-Object {
    # Nouvelle connexion TCP à chaque requête pour laisser le LB répartir.
    # -join : curl renvoie un tableau de lignes, sur lequel -match ne remplit pas $Matches.
    $html = (curl.exe -s --max-time 5 -H "Connection: close" "http://$ip/") -join "`n"
    if ($html -match "<strong>([^<]+)</strong>") { $servers[$Matches[1]] = 1 + $servers[$Matches[1]] }
}
$servers.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key) a répondu $($_.Value) fois" }
Test-Step "Le site répond via le Load Balancer" { $servers.Count -ge 1 }
Test-Step "Les $webCount VMs web reçoivent du trafic" { $servers.Count -ge $webCount }

Write-Host "`n=== 4. SSH via le NAT du Load Balancer ===" -ForegroundColor Cyan
# Ports NAT : 2201 -> web-1, 2202 -> web-2, ...
foreach ($port in (1..$webCount | ForEach-Object { 2200 + $_ })) {
    Test-Step "Port SSH $port ouvert" {
        (Test-NetConnection -ComputerName $ip -Port $port -WarningAction SilentlyContinue).TcpTestSucceeded
    }
}

Write-Host ""
if ($failures -eq 0) { Write-Host "TOUS LES TESTS SONT PASSÉS" -ForegroundColor Green }
else { Write-Host "$failures test(s) en échec" -ForegroundColor Red; exit 1 }
