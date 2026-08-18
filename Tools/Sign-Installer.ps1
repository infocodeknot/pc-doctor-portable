# ==========================================================
# PC Doctor Portable - Code-Signing Helper
# Code Knot Technology
# ==========================================================
# Signs the built installer with a code-signing certificate
# (.pfx) using PowerShell's Set-AuthenticodeSignature.
# SHA-256 hashing + RFC3161 timestamp server.
#
# Usage:
#   pwsh -File Tools\Sign-Installer.ps1 `
#       -PfxPath "C:\certs\mycert.pfx" -PfxPassword "secret"
#
# To avoid the Windows SmartScreen "Unknown publisher"
# warning you need a certificate from a public CA that
# Windows trusts (see README "Code Signing" section).
# ==========================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$PfxPath,

    [string]$PfxPassword = "",

    [string]$InstallerExe = ""
)

$Root = Split-Path -Parent $PSScriptRoot

if (-not $InstallerExe)
{
    $InstallerExe = Join-Path $Root "Installer\Output\PCDoctorPortable-Setup-1.2.exe"
}

if (-not (Test-Path $PfxPath))
{
    Write-Host ("Certificate not found : " + $PfxPath) -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $InstallerExe))
{
    Write-Host ("Installer not found : " + $InstallerExe) -ForegroundColor Red
    Write-Host "Build it first with Tools\Build-Installer.ps1"
    exit 1
}

Write-Host "Loading certificate..."
$Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
    $PfxPath,
    $PfxPassword
)

Write-Host ("Certificate : " + $Cert.Subject)
Write-Host ("Expires     : " + $Cert.NotAfter)

# RFC3161 timestamp server (DigiCert - public, no account needed)
$TimeStampServer = "http://timestamp.digicert.com"

Write-Host "Signing $InstallerExe ..."

$Result = Set-AuthenticodeSignature `
    -FilePath $InstallerExe `
    -Certificate $Cert `
    -TimestampServer $TimeStampServer `
    -HashAlgorithm SHA256

if ($Result.Status -eq "Valid")
{
    Write-Host "Signature valid. SmartScreen will trust this publisher (EV) or build reputation (OV)."
    exit 0
}
else
{
    Write-Host ("Signing status : " + $Result.Status) -ForegroundColor Red
    Write-Host ("Status message : " + $Result.StatusMessage) -ForegroundColor Red
    exit 1
}
