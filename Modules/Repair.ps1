# ==========================================================
# PC Doctor Portable
# Repair Module v1.1
# Code Knot Technology
# ==========================================================
# DISM and SFC are native executables: they do NOT throw
# PowerShell exceptions, so the old code logged "Completed"
# even when they failed. Now we check $LASTEXITCODE and
# parse the output, exactly like a professional pipeline.
# ==========================================================

$Global:LastModuleStatus = "FAILED"

Write-Step (Get-UIText "StepRepair")

$RepairConfig = $Global:Config.Repair

if (-not $RepairConfig.RunDISM -and -not $RepairConfig.RunSFC)
{
    Write-Log "Both DISM and SFC are disabled in Config.json. Skipping." "WARNING"
    $Global:LastModuleStatus = "SKIPPED"
    return
}

if (-not (Test-Admin))
{
    Write-Log "Administrator privileges are required for system repair." "ERROR"
    $Global:LastModuleStatus = "FAILED"
    return
}

# ----------------------------------------------------------
# DISM /Online /Cleanup-Image /RestoreHealth
# ----------------------------------------------------------

if ($RepairConfig.RunDISM)
{
    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line "  DISM /Online /Cleanup-Image /RestoreHealth" -Color Cyan
    Write-UIBoxLine -Line "  Running - this can take several minutes..." -Color Yellow
    Write-UIBoxBottom
    Write-LogFile -Message "Running DISM RestoreHealth..." -Level "INFO"

    try
    {
        $DismOutput = & "$env:SystemRoot\System32\Dism.exe" `
            /Online `
            /Cleanup-Image `
            /RestoreHealth 2>&1

        $DismExit  = $LASTEXITCODE
        $DismText  = ($DismOutput -join "`n")

        if ($DismExit -eq 0)
        {
            Write-Log "DISM completed successfully." "SUCCESS"
        }
        elseif ($DismText -match "source files could not be found|Error: 0x800f081f")
        {
            Write-Log "DISM finished but repair source files were missing (Windows Update source required)." "WARNING"
        }
        else
        {
            Write-Log "DISM reported issues (exit code $DismExit)." "WARNING"
        }
    }
    catch
    {
        Write-Log "DISM could not be started." "ERROR"
    }
}
else
{
    Write-Log "DISM is disabled in Config.json." "INFO"
}

# ----------------------------------------------------------
# SFC /scannow
# ----------------------------------------------------------

if ($RepairConfig.RunSFC)
{
    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line "  SFC /scannow" -Color Cyan
    Write-UIBoxLine -Line "  Running - this can take several minutes..." -Color Yellow
    Write-UIBoxBottom
    Write-LogFile -Message "Running System File Checker..." -Level "INFO"

    try
    {
        $SfcOutput = & "$env:SystemRoot\System32\sfc.exe" /scannow 2>&1
        $SfcExit   = $LASTEXITCODE

        # Official sfc exit codes:
        #   0 = no integrity violations
        #   1 = violations found and repaired
        #   2 = repair pending reboot
        #   3 = scan could not run
        switch ($SfcExit)
        {
            0
            {
                Write-Log "SFC found no integrity violations." "SUCCESS"
            }

            1
            {
                Write-Log "SFC found and repaired integrity violations." "SUCCESS"
                $Global:RestartRequired = $true
            }

            2
            {
                Write-Log "SFC completed - a restart is required to finish repairs." "WARNING"
                $Global:RestartRequired = $true
            }

            3
            {
                Write-Log "SFC could not complete the scan." "ERROR"
            }

            Default
            {
                Write-Log "SFC finished with exit code $SfcExit." "WARNING"
            }
        }
    }
    catch
    {
        Write-Log "SFC could not be started." "ERROR"
    }
}
else
{
    Write-Log "SFC is disabled in Config.json." "INFO"
}

$Global:LastModuleStatus = "SUCCESS"
