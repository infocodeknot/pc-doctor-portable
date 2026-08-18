# ==========================================================
# PC Doctor Portable - Self-Signed Certificate Generator
# Code Knot Technology
# ==========================================================
# Generates a self-signed code-signing certificate for
# testing. For production, use a CA-signed EV/OV cert.
#
# Usage (run as Administrator):
#   pwsh -File Tools\New-SignedCert.ps1
# ==========================================================

param(
    [string]$OutputPath = "Assets\PCDoctorCert.pfx",
    [string]$Password = "PCDoctor2026!"
)

$Root = Split-Path -Parent $PSScriptRoot
$CertPath = Join-Path $Root $OutputPath

Write-Host "Generating self-signed code-signing certificate..." -ForegroundColor Cyan

# Create self-signed cert with CodeSigning EKU
$Cert = New-SelfSignedCertificate `
    -Subject "CN=Code Knot Technology, O=Code Knot Technology, C=IN" `
    -Type CodeSigningCert `
    -KeyUsage DigitalSignature `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -NotAfter (Get-Date).AddYears(5) `
    -CertStoreLocation Cert:\CurrentUser\My `
    -HashAlgorithm SHA256

Write-Host "Certificate created:" -ForegroundColor Green
Write-Host "  Subject : $($Cert.Subject)"
Write-Host "  Thumbprint : $($Cert.Thumbprint)"
Write-Host "  Expires : $($Cert.NotAfter)"

# Export to PFX
$SecurePass = ConvertTo-SecureString -String $Password -Force -AsPlainText
$PfxBytes = $Cert.Export("Pfx", $SecurePass)

$PfxDir = Split-Path -Parent $CertPath
if (-not (Test-Path $PfxDir)) {
    New-Item -ItemType Directory -Path $PfxDir -Force | Out-Null
}

[System.IO.File]::WriteAllBytes($CertPath, $PfxBytes)

Write-Host ""
Write-Host "Certificate exported to:" -ForegroundColor Green
Write-Host "  $CertPath"
Write-Host "  Password: $Password"
Write-Host ""
Write-Host "To sign the installer:" -ForegroundColor Yellow
Write-Host "  pwsh -File Tools\Sign-Installer.ps1 -PfxPath '$CertPath' -PfxPassword '$Password'"
Write-Host ""
Write-Host "NOTE: This is a self-signed cert for TESTING only." -ForegroundColor DarkYellow
Write-Host "Windows SmartScreen will still show warnings." -ForegroundColor DarkYellow
Write-Host "For production, use a certificate from a trusted CA." -ForegroundColor DarkYellow
