# ==========================================================
# PC Doctor Portable
# Startup Module v1.1
# Code Knot Technology
# ==========================================================

function Show-Startup
{
    # 1) Configuration
    if ($Global:Config)
    {
        Write-UIStatusLine -Status "SUCCESS" -Message (Get-UIText "ConfigLoaded")
    }
    else
    {
        Write-UIStatusLine -Status "FAILED" -Message (Get-UIText "ConfigMissing")
    }

    # 2) Administrator - real check
    if (Test-Admin)
    {
        Write-UIStatusLine -Status "SUCCESS" -Message (Get-UIText "AdminOk")
    }
    else
    {
        Write-UIStatusLine -Status "WARNING" -Message (Get-UIText "AdminWarn")
        Write-LogFile -Message "Warning: not running as Administrator - repairs may fail." -Level "WARNING"
    }

    # 3) Environment - make sure runtime folders exist
    $Root = Split-Path -Parent $PSScriptRoot

    foreach ($FolderName in @("Logs","Reports","Backups","Temp"))
    {
        $FolderPath = Join-Path $Root $FolderName

        if (-not (Test-Path $FolderPath))
        {
            New-Item -ItemType Directory -Path $FolderPath -Force | Out-Null
        }
    }

    Write-UIStatusLine -Status "SUCCESS" -Message (Get-UIText "EnvReady")

    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + (Get-UIText "ReadyTitle")) -Color Green
    Write-UIBoxBottom
    Write-Host ""
}
