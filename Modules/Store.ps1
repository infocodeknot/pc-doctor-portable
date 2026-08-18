# ==========================================================
# PC Doctor Portable
# Microsoft Store Module v1.1
# Code Knot Technology
# ==========================================================
# Uses winget against the msstore source. Exit codes are
# checked so failures are never reported as success.
# ==========================================================

$Global:LastModuleStatus = "FAILED"

Write-Step (Get-UIText "StepStore")

if (-not $Global:Config.Store.Enabled)
{
    Write-Log "Microsoft Store updates are disabled in Config.json. Skipping." "WARNING"
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
    Write-Log "Microsoft Store Update Skipped." "WARNING"
    $Global:LastModuleStatus = "WARNING"
    return
}

Write-Log "Scanning Microsoft Store applications..." "INFO"

$StoreScan = & winget upgrade --source msstore --accept-source-agreements 2>&1
$ScanExit  = $LASTEXITCODE
$ScanText  = ($StoreScan -join "`n")

if ($ScanExit -eq 0 -and $ScanText -match "No applicable update|No installed package has available upgrades")
{
    Write-Log (Get-UIText "StoreUpToDate") "SUCCESS"
    $Global:LastModuleStatus = "SUCCESS"
    return
}

if ($ScanExit -ne 0)
{
    Write-Log "Microsoft Store scan failed (exit code $ScanExit). Skipping updates." "WARNING"
    $Global:LastModuleStatus = "WARNING"
    return
}

Write-Log "Store application updates found. Installing (this can take a while)..." "INFO"

& winget upgrade `
    --source msstore `
    --all `
    --silent `
    --disable-interactivity `
    --accept-package-agreements `
    --accept-source-agreements 2>&1 | Out-Null

$InstallExit = $LASTEXITCODE

if ($InstallExit -eq 0)
{
    Write-Log (Get-UIText "StoreUpdatesDone") "SUCCESS"
    $Global:LastModuleStatus = "SUCCESS"
}
else
{
    Write-Log "Some Microsoft Store applications could not be updated (exit code $InstallExit)." "WARNING"
    $Global:LastModuleStatus = "WARNING"
}
