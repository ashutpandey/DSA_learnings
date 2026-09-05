#Requires -Version 5.1
<#
.SYNOPSIS
    Cleanup: removes all artifacts created by New-LNKDemo.ps1

.DESCRIPTION
    Deletes the LNK shortcut, decoy PDF, execution log, and the HKCU Run
    persistence key written during the demo. Parameters must match the values
    used when New-LNKDemo.ps1 was run (defaults are identical).

.PARAMETER OutputDir
    Directory where the LNK was placed. Default: Desktop.

.PARAMETER DocName
    Base name used when building the demo. Default: Q3_Financial_Report_2024.

.PARAMETER PersistKey
    Registry value name under HKCU Run. Default: AdobeAcrobat_Update.

.EXAMPLE
    .\Remove-LNKDemo.ps1
    Cleans up default demo artifacts.

.EXAMPLE
    .\Remove-LNKDemo.ps1 -DocName "Invoice_Nov_2024" -PersistKey "AdobeAcrobat_Update"
    Cleans up a custom-named demo run.
#>
[CmdletBinding()]
param(
    [string] $OutputDir  = "$env:USERPROFILE\Desktop",
    [string] $DocName    = "Q3_Financial_Report_2024",
    [string] $PersistKey = "AdobeAcrobat_Update"
)

$ErrorActionPreference = 'SilentlyContinue'

$lnkPath    = Join-Path $OutputDir "$DocName.pdf.lnk"
$decoyPath  = Join-Path $env:TEMP  "$DocName.pdf"
$logPath    = Join-Path $env:TEMP  "demo_execution_log.txt"
$regRunPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'

Write-Host ""
Write-Host "  [*] Remove-LNKDemo — cleaning up demo artifacts" -ForegroundColor Yellow
Write-Host ""

# Files
foreach ($f in @($lnkPath, $decoyPath, $logPath)) {
    if (Test-Path $f) {
        Remove-Item $f -Force
        Write-Host "  Removed  : $f" -ForegroundColor DarkGray
    } else {
        Write-Host "  Not found: $f  (already removed or never created)" -ForegroundColor DarkGray
    }
}

# Registry persistence key
$keyExists = Get-ItemProperty -Path $regRunPath -Name $PersistKey -ErrorAction SilentlyContinue
if ($keyExists) {
    Remove-ItemProperty -Path $regRunPath -Name $PersistKey -Force
    Write-Host "  Removed  : HKCU\...\Run\$PersistKey" -ForegroundColor DarkGray
} else {
    Write-Host "  Not found: HKCU\...\Run\$PersistKey  (key not present — LNK may not have been triggered)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  [+] Cleanup complete." -ForegroundColor Green
Write-Host ""
