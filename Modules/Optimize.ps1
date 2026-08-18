# ==========================================================
# PC Doctor Portable
# Optimization Module v1.1
# Code Knot Technology
# ==========================================================
# Honors Config.json > Optimization:
#   OptimizeDrives       - ReTrim SSDs, skip HDDs (Windows schedules those)
#   RestartExplorer      - restart Windows Explorer shell
#   ClearThumbnailCache  - thumbnail + icon cache
# ==========================================================

$Global:LastModuleStatus = "FAILED"

Write-Step (Get-UIText "StepOptimization")

$OptimizeConfig = $Global:Config.Optimization

$AnyEnabled = @(
    $OptimizeConfig.OptimizeDrives,
    $OptimizeConfig.RestartExplorer,
    $OptimizeConfig.ClearThumbnailCache
) | Where-Object { $_ }

if (-not $AnyEnabled)
{
    Write-Log "No optimization tasks are enabled in Config.json. Skipping." "WARNING"
    $Global:LastModuleStatus = "SKIPPED"
    return
}

# ----------------------------------------------------------
# Interactive Mode
# ----------------------------------------------------------

if ($Global:AppMode -eq "INTERACTIVE")
{
    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + (Get-UIText "OptimizeConfirm")) -Color Yellow
    Write-UIBoxLine -Line ""
    Write-UIBoxLine -Line ("  " + (Get-UIText "OptimizeYes")) -Color Green
    Write-UIBoxLine -Line ("  " + (Get-UIText "OptimizeNo")) -Color Yellow
    Write-UIBoxBottom
    Write-Host ""

    $Choice = (Read-Host (Get-UIText "SelectPrompt")).ToUpper()

    if ($Choice -ne "Y")
    {
        Write-Log "Optimization skipped by user." "WARNING"
        $Global:LastModuleStatus = "SKIPPED"
        return
    }
}

# ----------------------------------------------------------
# Thumbnail Cache
# ----------------------------------------------------------

if ($OptimizeConfig.ClearThumbnailCache)
{
    try
    {
        Write-Log "Cleaning Thumbnail Cache..." "INFO"

        Remove-Item `
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*" `
            -Force `
            -ErrorAction SilentlyContinue

        Remove-Item `
            "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*" `
            -Force `
            -ErrorAction SilentlyContinue

        Write-Log "Thumbnail Cache Cleaned." "SUCCESS"
    }
    catch
    {
        Write-Log "Thumbnail Cache Cleanup Skipped." "WARNING"
    }
}
else
{
    Write-Log "Thumbnail cache cleanup is disabled in Config.json." "INFO"
}

# ----------------------------------------------------------
# Optimize Drives
# ----------------------------------------------------------

if ($OptimizeConfig.OptimizeDrives)
{
    try
    {
        Write-Log "Optimizing Drives..." "INFO"

        Get-Volume -ErrorAction SilentlyContinue |
            Where-Object { $_.DriveLetter -and $_.DriveType -eq "Fixed" } |
            ForEach-Object {

                $Letter = $_.DriveLetter

                if ($_.MediaType -eq "SSD")
                {
                    Write-Log "Drive $Letter : ReTrim (SSD)..." "INFO"
                    Optimize-Volume -DriveLetter $Letter -ReTrim -ErrorAction SilentlyContinue
                }
                else
                {
                    Write-Log "Drive $Letter : HDD - defragmentation is already scheduled by Windows." "INFO"
                }
            }

        Write-Log "Drive Optimization Completed." "SUCCESS"
    }
    catch
    {
        Write-Log "Drive Optimization Skipped." "WARNING"
    }
}
else
{
    Write-Log "Drive optimization is disabled in Config.json." "INFO"
}

# ----------------------------------------------------------
# Restart Explorer
# ----------------------------------------------------------

if ($OptimizeConfig.RestartExplorer)
{
    try
    {
        Write-Log "Restarting Windows Explorer..." "INFO"

        Stop-Process -Name explorer -Force -ErrorAction Stop
        Start-Sleep 2
        Start-Process explorer.exe

        Write-Log "Explorer restarted." "SUCCESS"
    }
    catch
    {
        # Explorer may have already been closed/crashed - bring it back
        Start-Process explorer.exe -ErrorAction SilentlyContinue
        Write-Log "Explorer restart handled (it may already be running)." "WARNING"
    }
}
else
{
    Write-Log "Explorer restart is disabled in Config.json." "INFO"
}

Write-Log (Get-UIText "OptimizationCompleted") "SUCCESS"
$Global:LastModuleStatus = "SUCCESS"
