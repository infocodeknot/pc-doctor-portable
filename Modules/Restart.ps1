# ==========================================================
# PC Doctor Portable
# Restart Manager Module v1.1
# Code Knot Technology
# ==========================================================
# AUTO mode never blocks on a prompt: it follows
# Config.json > Restart > AutoRestart. INTERACTIVE mode
# asks the user. Control always returns to Main.ps1 so
# the execution summary is shown.
# ==========================================================

$Global:LastModuleStatus = "FAILED"

Write-Step (Get-UIText "StepRestart")

if (-not $Global:RestartRequired)
{
    Write-LogFile -Message "System is already up to date." -Level "SUCCESS"
    Write-LogFile -Message (Get-UIText "RestartNotRequired") -Level "SUCCESS"

    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + (Get-UIText "SystemReady")) -Color Green
    Write-UIBoxBottom
    Write-Host ""

    $Global:LastModuleStatus = "SUCCESS"
    return
}

Write-Log (Get-UIText "RestartRequired") "WARNING"

# ----------------------------------------------------------
# AUTO MODE - no prompts
# ----------------------------------------------------------

if ($Global:AppMode -eq "AUTO")
{
    if ($Global:Config.Restart.AutoRestart)
    {
        Write-Log "Auto restart is enabled - restarting now..." "INFO"

        Show-UISpinner -Seconds 5 -Label "Restarting computer"

        Restart-Computer -Force
    }
    else
    {
        Write-Log "A system restart is recommended to finish applying changes." "WARNING"
        Write-Log "Please restart the computer manually." "WARNING"
        $Global:LastModuleStatus = "WARNING"
    }

    return
}

# ----------------------------------------------------------
# INTERACTIVE MODE
# ----------------------------------------------------------

Write-Host ""
Write-UIBoxTop
Write-UIBoxLine -Line ("  " + (Get-UIText "RestartRecommended")) -Color Yellow
Write-UIBoxLine -Line ""
Write-UIBoxLine -Line ("  " + (Get-UIText "RestartNowOpt")) -Color Green
Write-UIBoxLine -Line ("  " + (Get-UIText "RestartLaterOpt")) -Color Yellow
Write-UIBoxBottom
Write-Host ""

$Choice = (Read-Host (Get-UIText "SelectPrompt")).ToUpper()

switch ($Choice)
{
    "Y"
    {
        Write-Log "Restart initiated by user." "INFO"
        Show-UISpinner -Seconds 5 -Label "Restarting computer"
        Restart-Computer -Force
    }

    Default
    {
        Write-Log "Restart postponed by user." "INFO"
        $Global:LastModuleStatus = "WARNING"
    }
}
