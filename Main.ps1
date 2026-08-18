# ==========================================================
# PC Doctor Portable v1.2
# Main Controller
# Code Knot Technology
# ==========================================================
# Single entry point. try/finally guarantees the log writer
# is always closed, and every module's result (with
# duration) is collected for the summary and report.
#
# Parameters:
#   -Mode AUTO|INTERACTIVE   skip the menu (used by the GUI
#                            launcher, which always runs AUTO)
# ==========================================================

param(
    [ValidateSet("AUTO","INTERACTIVE")]
    [string]$Mode = "",

    # Used by the GUI: path to a user-writable copy of Config.json
    [string]$ConfigPath = "",

    # Set when launched by the Windows Scheduled Task: shows a
    # completion toast so background runs are noticed
    [switch]$Scheduled
)

$ErrorActionPreference = "Stop"

$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$Modules = Join-Path $Root "Modules"

# ----------------------------------------------------------
# Load Core Modules
# ----------------------------------------------------------

. (Join-Path $Modules "Logger.ps1")
. (Join-Path $Modules "UI.ps1")
. (Join-Path $Modules "Common.ps1")
. (Join-Path $Modules "Update.ps1")
. (Join-Path $Modules "TaskScheduler.ps1")
. (Join-Path $Modules "Banner.ps1")
. (Join-Path $Modules "Startup.ps1")
. (Join-Path $Modules "Menu.ps1")

try
{
    Load-Config -ConfigPath $ConfigPath

    # ------------------------------------------------------
    # Initialize Global Variables
    # ------------------------------------------------------

    $Global:ModuleResults      = @()
    $Global:RestartRequired    = $false
    $Global:SkipOnlineModules  = $false
    $Global:AppExit            = $false
    $Global:TotalModules       = 12

    # ------------------------------------------------------
    # Start Application
    # ------------------------------------------------------

    Show-Banner
    Show-Startup

    # Replace the PowerShell console icon with the toolkit's own
    # branding in the title bar / taskbar while the app runs.
    Set-ConsoleIcon -IconPath (Join-Path $Root "Assets\PCDoctor.ico")

    if ($Mode)
    {
        $Global:AppMode = $Mode
        Write-LogFile -Message "Mode supplied via command line: $Mode." -Level "INFO"
    }
    else
    {
        Show-Menu
    }

    if ($Global:AppExit)
    {
        Write-Host ""
        Write-UIBoxTop
        Write-UIBoxLine -Line "  Application exited by user." -Color Yellow
        Write-UIBoxBottom
        Write-Host ""

        Write-LogFile -Message "Application exited by user." -Level "INFO"
        return
    }

    # Mode badge
    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + (Get-UIText "ModeBadge") + " : " + $Global:AppMode.ToUpper()) -Color Cyan
    Write-UIBoxBottom
    Write-Host ""

    Write-LogFile -Message "PC Doctor Portable Started (Mode: $Global:AppMode)." -Level "SUCCESS"

    # ------------------------------------------------------
    # Execute Modules
    # ------------------------------------------------------

    Run-Module "Internet Check"     "Internet.ps1"

    # Non-pipeline: check for a newer release on GitHub
    Test-AppUpdate `
        -UpdateUrl $Global:Config.General.UpdateUrl `
        -CurrentVersion $Global:Config.General.Version

    Run-Module "Restore Point"      "Restore.ps1"
    Run-Module "Windows Update"     "WindowsUpdate.ps1"
    Run-Module "Driver Update"      "Drivers.ps1"
    Run-Module "Software Update"    "Winget.ps1"
    Run-Module "Microsoft Store"    "Store.ps1"
    Run-Module "Windows Repair"     "Repair.ps1"
    Run-Module "Cleanup"            "Cleanup.ps1"
    Run-Module "Optimization"       "Optimize.ps1"
    Run-Module "Verification"       "Verification.ps1"
    Run-Module "Report"             "Report.ps1"
    Run-Module "Restart Manager"    "Restart.ps1"

    # ------------------------------------------------------
    # Execution Summary
    # ------------------------------------------------------

    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + (Get-UIText "ExecSummary")) -Color Yellow
    Write-UIBoxLine -Line ""
    foreach ($Item in $Global:ModuleResults)
    {
        $Chip  = Get-UIStatusChip -Status $Item.Status
        $Color = Get-UIStatusColor -Status $Item.Status
        $Line  = ("  {0,-24} {1}  {2}" -f $Item.Module, $Chip, $Item.Duration)

        Write-UIBoxLine -Line $Line -Color $Color
    }
    Write-UIBoxBottom

    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + (Get-UIText "ToolFinished")) -Color Green
    Write-UIBoxBottom
    Write-Host ""

    Write-LogFile -Message "Tool Finished." -Level "SUCCESS"
}
catch
{
    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line "  FATAL ERROR" -Color Red
    Write-UIBoxLine -Line ("  " + $_.Exception.Message) -Color Red
    Write-UIBoxBottom
    Write-Host ""

    Write-LogFile -Message "FATAL ERROR : $($_.Exception.Message)" -Level "ERROR"
}
finally
{
    Close-Logger

    # Background (scheduled-task) runs: record a summary entry so
    # the GUI history view can show scheduled-run badges, and
    # notify the user (unless notifications are switched off).
    if ($Scheduled -and $Global:ModuleResults.Count -gt 0)
    {
        $Ok   = @($Global:ModuleResults | Where-Object { $_.Status -eq "SUCCESS" }).Count
        $Warn = @($Global:ModuleResults | Where-Object { $_.Status -in @("WARNING", "SKIPPED") }).Count
        $Fail = @($Global:ModuleResults | Where-Object { $_.Status -eq "FAILED" }).Count

        $Status = if ($Fail -gt 0) { "FAILED" } elseif ($Warn -gt 0) { "WARNING" } else { "SUCCESS" }

        $SummaryDir = Join-Path $env:APPDATA "PCDoctorPortable"
        $SummaryFile = Join-Path $SummaryDir "scheduled-runs.json"

        try
        {
            New-Item -ItemType Directory -Path $SummaryDir -Force | Out-Null

            $Entries = @()

            if (Test-Path $SummaryFile)
            {
                $Entries = @(Get-Content $SummaryFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json)
            }

            $Entries += [PSCustomObject]@{
                Date   = (Get-Date -Format "yyyy-MM-dd HH:mm")
                Ok     = $Ok
                Warn   = $Warn
                Fail   = $Fail
                Status = $Status
            }

            $Entries | ConvertTo-Json -Depth 5 | Set-Content $SummaryFile -Encoding UTF8
        }
        catch {}

        $ShowToast = $true
        if ($Global:Config.General -and $Global:Config.General.PSObject.Properties.Name -contains "ShowToast")
        {
            $ShowToast = [bool]$Global:Config.General.ShowToast
        }

        if ($ShowToast)
        {
            Send-PCToast `
                -Title "PC Doctor Portable" `
                -Message ("Maintenance completed - {0} OK, {1} warnings, {2} failed. See Reports/ for details." -f $Ok, $Warn, $Fail)
        }
    }
}
