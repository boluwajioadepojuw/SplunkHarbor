# SplunkHarbor - deploy the Universal Forwarder on a Windows endpoint
# Usage (admin PowerShell):
#   .\deploy-forwarder.ps1 -SplunkHost 192.168.x.x [-UfPath C:\path\splunkforwarder.msi] [-Port 9997]

param(
    [Parameter(Mandatory = $true)][string]$SplunkHost,
    [string]$UfPath = "",
    [int]$Port = 9997
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host "[lh] $Message" -ForegroundColor Cyan
}

Write-Step "checking for the forwarder installer"
if (-not $UfPath) {
    $UfPath = Get-ChildItem -Path "$PSScriptRoot" -Filter "splunkforwarder*.msi" |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $UfPath -or -not (Test-Path $UfPath)) {
    throw "put the splunkforwarder .msi next to this script or pass -UfPath"
}

$QuotedMsi = [char]34 + $UfPath + [char]34
$Target = $SplunkHost + ":" + $Port

Write-Step "installing $UfPath quietly"
$MsiArgs = @(
    "/i", $QuotedMsi,
    "AGREETOLICENSE=Yes",
    ("RECEIVING_INDEXER=" + [char]34 + $Target + [char]34),
    "WINEVENTLOG_SEC_ENABLE=1",
    "WINEVENTLOG_SYS_ENABLE=1",
    "WINEVENTLOG_APP_ENABLE=1",
    "LAUNCHSPLUNK=1",
    "SERVICESTARTTYPE=auto",
    "/quiet"
)
Start-Process msiexec.exe -ArgumentList $MsiArgs -Wait

Write-Step "adding Sysmon to the inputs"
$InputsPath = "C:\Program Files\SplunkUniversalForwarder\etc\apps\splunkharbor_forwarder\local"
New-Item -ItemType Directory -Force -Path $InputsPath | Out-Null
$InputsConf = @"
[WinEventLog://Microsoft-Windows-Sysmon/Operational]
disabled = 0
index = win
renderXml = false
"@
Set-Content -Path ($InputsPath + "\inputs.conf") -Value $InputsConf

Write-Step "restarting the forwarder service"
Restart-Service SplunkForwarder
Write-Step "done - check Splunk with: index=win | stats count by host"
