# ==========================================================
# PC Doctor Portable - Installer Build Helper
# Code Knot Technology
# ==========================================================
# 1. Generates Assets\PCDoctor.ico (if missing)
# 2. Locates Inno Setup 6 (ISCC.exe)
# 3. Compiles Installer\PCDoctorPortable.iss
#
# If Inno Setup is not installed, prints the command to
# install it:  winget install -e --id JRSoftware.InnoSetup
# ==========================================================

param(
    [switch]$SkipIcon,

    # Optional: sign the built installer with a code-signing cert
    [string]$SignPfxPath = "",
    [string]$SignPfxPassword = ""
)

$Root = Split-Path -Parent $PSScriptRoot

if (-not $SkipIcon)
{
    $IconPath = Join-Path $Root "Assets\PCDoctor.ico"

    if (-not (Test-Path $IconPath))
    {
        Write-Host "Generating application icon..."
        & (Join-Path $PSScriptRoot "New-AppIcon.ps1")
    }
    else
    {
        Write-Host "Icon already present."
    }
}

$Candidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 7\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles(x86)\Inno Setup 7\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 7\ISCC.exe",
    "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)

$ISCC = $Candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $ISCC)
{
    Write-Host ""
Write-Host "Inno Setup was not found. Install it with:"
Write-Host ""
Write-Host "    winget install -e --id JRSoftware.InnoSetup"
    Write-Host ""
    Write-Host "Then run this script again."
    exit 1
}

Write-Host ("Using Inno Setup : " + $ISCC)
Write-Host "Compiling installer..."

$IssFile = Join-Path $Root "Installer\PCDoctorPortable.iss"

& $ISCC $IssFile

if ($LASTEXITCODE -eq 0)
{
    Write-Host ""
    Write-Host "Installer built : Installer\Output\PCDoctorPortable-Setup-1.2.exe"

    if ($SignPfxPath)
    {
        Write-Host ""
        Write-Host "Signing the installer..."

        & (Join-Path $PSScriptRoot "Sign-Installer.ps1") `
            -PfxPath $SignPfxPath `
            -PfxPassword $SignPfxPassword

        exit $LASTEXITCODE
    }
}
else
{
    Write-Host ""
    Write-Host "Installer build failed (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}
