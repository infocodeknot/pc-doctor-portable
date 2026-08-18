# ==========================================================
# PC Doctor Portable
# Restore Point Module v1.1
# Code Knot Technology
# ==========================================================
# Uses the registry DisableSR value to detect whether
# System Restore is really enabled, and targets the
# actual system drive instead of a hardcoded C:.
# ==========================================================

$Global:LastModuleStatus = "FAILED"

Write-Step (Get-UIText "StepRestore")

if (-not $Global:Config.RestorePoint.Enabled)
{
    Write-Log "Restore Point is disabled in Config.json. Skipping." "WARNING"
    $Global:LastModuleStatus = "SKIPPED"
    return
}

$SystemDrive = $env:SystemDrive.TrimEnd("\")

# ----------------------------------------------------------
# Is System Restore enabled? (registry is the source of truth)
# ----------------------------------------------------------

$RestoreEnabled = $true

try
{
    $DisableSR = (Get-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" `
        -Name DisableSR `
        -ErrorAction SilentlyContinue).DisableSR

    if ($DisableSR -eq 1) { $RestoreEnabled = $false }
}
catch
{
    $RestoreEnabled = $false
}

# ----------------------------------------------------------
# AUTO MODE
# ----------------------------------------------------------

if ($Global:AppMode -eq "AUTO")
{
    if (-not $RestoreEnabled)
    {
        Write-Log (Get-UIText "RestorePointSkipped") "WARNING"
        Write-Log "Reason : System Restore is disabled." "WARNING"
        $Global:LastModuleStatus = "SKIPPED"
        return
    }

    try
    {
        Checkpoint-Computer `
            -Description "PC Doctor Portable Restore Point" `
            -RestorePointType MODIFY_SETTINGS `
            -ErrorAction Stop

        Write-Log (Get-UIText "RestorePointCreated") "SUCCESS"
        $Global:LastModuleStatus = "SUCCESS"
    }
    catch
    {
        Write-Log "Restore Point could not be created : $($_.Exception.Message)" "WARNING"
        $Global:LastModuleStatus = "WARNING"
    }

    return
}

# ----------------------------------------------------------
# INTERACTIVE MODE
# ----------------------------------------------------------

if (-not $RestoreEnabled)
{
    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + (Get-UIText "RestoreDisabled")) -Color Yellow
    Write-UIBoxLine -Line ""
    Write-UIBoxLine -Line ("  " + (Get-UIText "EnableCreateOpt")) -Color Green
    Write-UIBoxLine -Line ("  " + (Get-UIText "SkipRestoreOpt")) -Color Yellow
    Write-UIBoxBottom
    Write-Host ""

    $Choice = (Read-Host (Get-UIText "SelectPrompt")).ToUpper()

    if ($Choice -eq "Y")
    {
        try
        {
            Enable-ComputerRestore -Drive $SystemDrive -ErrorAction Stop

            Checkpoint-Computer `
                -Description "PC Doctor Portable Restore Point" `
                -RestorePointType MODIFY_SETTINGS `
                -ErrorAction Stop

            Write-Log "Restore Point Created Successfully." "SUCCESS"
            $Global:LastModuleStatus = "SUCCESS"
        }
        catch
        {
            Write-Log "Unable to create Restore Point : $($_.Exception.Message)" "WARNING"
            $Global:LastModuleStatus = "WARNING"
        }
    }
    else
    {
        Write-Log "Restore Point skipped by user." "WARNING"
        $Global:LastModuleStatus = "SKIPPED"
    }

    return
}

try
{
    Checkpoint-Computer `
        -Description "PC Doctor Portable Restore Point" `
        -RestorePointType MODIFY_SETTINGS `
        -ErrorAction Stop

    Write-Log "Restore Point Created Successfully." "SUCCESS"
    $Global:LastModuleStatus = "SUCCESS"
}
catch
{
    Write-Log "Restore Point could not be created : $($_.Exception.Message)" "WARNING"
    $Global:LastModuleStatus = "WARNING"
}
