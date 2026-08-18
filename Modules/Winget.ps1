# ==========================================================
# PC Doctor Portable
# Software Update Module v1.1
# Code Knot Technology
# ==========================================================
# Winget is a native executable: exit codes are checked on
# every call so a failed scan/install is never mistaken for
# "everything is up to date".
# ==========================================================

$Global:LastModuleStatus = "FAILED"

Write-Step (Get-UIText "StepSoftware")

if (-not $Global:Config.Winget.Enabled)
{
    Write-Log "Software updates are disabled in Config.json. Skipping." "WARNING"
    $Global:LastModuleStatus = "SKIPPED"
    return
}

if ($Global:SkipOnlineModules)
{
    $Global:LastModuleStatus = "SKIPPED"
    return
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue))
{
    Write-Log "Winget is not available." "WARNING"
    Write-Log "Software Update Skipped." "WARNING"
    $Global:LastModuleStatus = "WARNING"
    return
}

Write-Log "Scanning installed software..." "INFO"

$ScanResult = & winget upgrade --accept-source-agreements 2>&1
$ScanExit   = $LASTEXITCODE
$ScanText   = ($ScanResult -join "`n")

if ($ScanExit -eq 0 -and $ScanText -match "No applicable update|No installed package has available upgrades")
{
    Write-Log (Get-UIText "AllUpToDate") "SUCCESS"
    $Global:LastModuleStatus = "SUCCESS"
    return
}

if ($ScanExit -ne 0)
{
    Write-Log "winget scan failed (exit code $ScanExit). Skipping updates." "WARNING"
    $Global:LastModuleStatus = "WARNING"
    return
}

Write-Log "Software updates found. Installing (this can take a while)..." "INFO"

& winget upgrade `
    --all `
    --include-unknown `
    --silent `
    --disable-interactivity `
    --accept-package-agreements `
    --accept-source-agreements 2>&1 | Out-Null

$InstallExit = $LASTEXITCODE

if ($InstallExit -eq 0)
{
    Write-Log (Get-UIText "SoftwareUpdatesDone") "SUCCESS"
    $Global:LastModuleStatus = "SUCCESS"
}
else
{
    Write-Log "Some software could not be updated (exit code $InstallExit)." "WARNING"
    $Global:LastModuleStatus = "WARNING"
}
