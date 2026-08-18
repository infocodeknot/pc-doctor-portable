# ==========================================================
# PC Doctor Portable - Pester test runner
#   pwsh -File Tools\Run-Tests.ps1
# Runs every *.Tests.ps1 under Tests\ and exits non-zero on
# failure (CI-friendly). Works with Pester 3.4 (bundled with
# Windows) and 5.x.
# ==========================================================

param(
    [string]$Path = (Join-Path $PSScriptRoot "..\Tests")
)

$ErrorActionPreference = "Stop"

$Pester = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1

if (-not $Pester)
{
    Write-Host "Pester is not installed. Install it with: Install-Module Pester -Scope CurrentUser -Force"
    exit 2
}

Import-Module $Pester -Force

Write-Host ("Using Pester " + $Pester.Version.ToString())

$Result = Invoke-Pester -Path $Path -PassThru

$Failed = $Result.FailedCount

Write-Host ""
Write-Host ("Tests passed : " + $Result.PassedCount)
Write-Host ("Tests failed : " + $Failed)

if ($Failed -gt 0)
{
    exit 1
}

exit 0
