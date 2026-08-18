# ==========================================================
# PC Doctor Portable
# Verification Module v1.1
# Code Knot Technology
# ==========================================================
# Verification is now derived from the REAL module results
# collected by the runner - no hardcoded "COMPLETED" values.
# ==========================================================

$Global:LastModuleStatus = "FAILED"

Write-Step (Get-UIText "StepVerification")

$Verification = [PSCustomObject]@{
    Internet      = "Unknown"
    WindowsUpdate = "Unknown"
    Drivers       = "Unknown"
    Software      = "Unknown"
    Store         = "Unknown"
    Repair        = "Unknown"
    Cleanup       = "Unknown"
    Optimization  = "Unknown"
    Restart       = "Unknown"
    Administrator = "Unknown"
    DiskSpace     = "Unknown"
    OverallStatus = "Unknown"
}

# ----------------------------------------------------------
# Map real module results onto the verification fields
# ----------------------------------------------------------

$StatusMap = @{
    "Internet Check"  = "Internet"
    "Windows Update"  = "WindowsUpdate"
    "Driver Update"   = "Drivers"
    "Software Update" = "Software"
    "Microsoft Store" = "Store"
    "Windows Repair"  = "Repair"
    "Cleanup"         = "Cleanup"
    "Optimization"    = "Optimization"
}

foreach ($Result in $Global:ModuleResults)
{
    if ($StatusMap.ContainsKey($Result.Module))
    {
        $Field = $StatusMap[$Result.Module]
        $Verification.$Field = $Result.Status
    }
}

# ----------------------------------------------------------
# Live checks
# ----------------------------------------------------------

try
{
    $Verification.Internet = if (Test-Connection "1.1.1.1" -Count 1 -Quiet) { "OK" } else { "FAILED" }
}
catch
{
    $Verification.Internet = "FAILED"
}

try
{
    if (Get-Command winget -ErrorAction SilentlyContinue)
    {
        $Verification.Software = "OK"
        $Verification.Store    = "OK"
    }
    else
    {
        $Verification.Software = "NOT AVAILABLE"
        $Verification.Store    = "NOT AVAILABLE"
    }
}
catch {}

$Verification.Restart = if ($Global:RestartRequired) { "REQUIRED" } else { "NOT REQUIRED" }
$Verification.Administrator = if (Test-Admin) { "YES" } else { "NO" }

try
{
    $SystemLetter = $env:SystemDrive.TrimEnd(":")
    $Drive = Get-PSDrive $SystemLetter

    $Verification.DiskSpace = ("{0} GB Free" -f [math]::Round($Drive.Free / 1GB, 2))
}
catch
{
    $Verification.DiskSpace = "Unknown"
}

# ----------------------------------------------------------
# Overall status
# ----------------------------------------------------------

$FailedModules = @($Global:ModuleResults | Where-Object { $_.Status -eq "FAILED" })

if ($FailedModules.Count -gt 0 -or $Verification.Administrator -eq "NO")
{
    $Verification.OverallStatus = "ATTENTION REQUIRED"
}
else
{
    $Verification.OverallStatus = "HEALTHY"
}

$Global:Verification = $Verification

Write-Log (Get-UIText "VerificationCompleted") "SUCCESS"
$Global:LastModuleStatus = "SUCCESS"
