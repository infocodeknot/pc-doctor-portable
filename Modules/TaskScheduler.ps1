# ==========================================================
# PC Doctor Portable
# Task Scheduler Module v1.0
# Code Knot Technology
# ==========================================================
# Registers a Windows Scheduled Task that runs the toolkit
# (Main.ps1 -Mode AUTO) weekly at a fixed day/time - so the
# app works even when the GUI is not running. Backed by
# schtasks.exe (no module dependencies). Registration with
# highest privileges requires an elevated session.
# ==========================================================

$Script:DefaultTaskName = "PC Doctor Portable Auto Run"

function Get-PCTaskName
{
    param([string]$TaskName = "")

    if (-not $TaskName) { return $Script:DefaultTaskName }

    return $TaskName
}

# True when the scheduled task exists
function Test-PCScheduledTask
{
    param([string]$TaskName = "")

    $Name = Get-PCTaskName -TaskName $TaskName

    schtasks.exe /Query /TN $Name 2>$null | Out-Null

    return ($LASTEXITCODE -eq 0)
}

# Builds the command line the scheduled task executes
function Get-PCTaskCommand
{
    param(
        [string]$MainPath = "",
        [string]$ConfigPath = ""
    )

    if (-not $MainPath)
    {
        $MainPath = Join-Path $PSScriptRoot "..\Main.ps1"
    }

    $MainPath = [System.IO.Path]::GetFullPath($MainPath)

    # -Scheduled tells Main.ps1 to show a completion toast so the
    # user notices background runs that happen while the GUI is
    # closed; -WindowStyle Hidden keeps the console from flashing.
    $Command = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Mode AUTO -Scheduled' -f $MainPath

    if (-not $ConfigPath)
    {
        $AppDataConfig = Join-Path $env:APPDATA "PCDoctorPortable\Config.json"

        if (Test-Path $AppDataConfig)
        {
            $ConfigPath = $AppDataConfig
        }
    }

    if ($ConfigPath)
    {
        $Command += ' -ConfigPath "{0}"' -f [System.IO.Path]::GetFullPath($ConfigPath)
    }

    return $Command
}

# Day: 0 = every day, 1..7 = Sunday..Saturday
function Register-PCScheduledTask
{
    param(
        [int]$Day = 0,
        [string]$Time = "09:00",
        [string]$TaskName = "",
        [string]$MainPath = "",
        [string]$ConfigPath = ""
    )

    $Name = Get-PCTaskName -TaskName $TaskName

    if (-not (Test-Admin))
    {
        Write-Log "Task Scheduler registration requires an elevated session." "WARNING"
        return $false
    }

    if ($Day -lt 0 -or $Day -gt 7)
    {
        Write-Log "Invalid schedule day: $Day (use 0 = every day, 1..7 = Sunday..Saturday)." "ERROR"
        return $false
    }

    if ($Time -notmatch "^\d{2}:\d{2}$")
    {
        Write-Log "Invalid schedule time: $Time (use HH:mm)." "ERROR"
        return $false
    }

    $Schedule = if ($Day -eq 0) { "DAILY" } else { "WEEKLY" }

    $DayArg = if ($Day -eq 0) { "" } else { @("SUN","MON","TUE","WED","THU","FRI","SAT")[$Day - 1] }

    $Command = Get-PCTaskCommand -MainPath $MainPath -ConfigPath $ConfigPath

    $Arguments = @("/Create", "/TN", $Name, "/TR", $Command,
                   "/SC", $Schedule, "/ST", $Time, "/RL", "HIGHEST", "/F")

    if ($DayArg)
    {
        $Arguments += @("/D", $DayArg)
    }

    schtasks.exe @Arguments 2>$null | Out-Null

    if ($LASTEXITCODE -eq 0)
    {
        Write-Log "Scheduled task registered : $Name ($Schedule $DayArg $Time)." "SUCCESS"
        return $true
    }

    Write-Log "Failed to register the scheduled task (exit code $LASTEXITCODE)." "ERROR"
    return $false
}

function Unregister-PCScheduledTask
{
    param([string]$TaskName = "")

    $Name = Get-PCTaskName -TaskName $TaskName

    if (-not (Test-PCScheduledTask -TaskName $Name))
    {
        Write-Log "No scheduled task to remove ($Name)." "INFO"
        return $true
    }

    if (-not (Test-Admin))
    {
        Write-Log "Task removal requires an elevated session." "WARNING"
        return $false
    }

    schtasks.exe /Delete /TN $Name /F 2>$null | Out-Null

    if ($LASTEXITCODE -eq 0)
    {
        Write-Log "Scheduled task removed : $Name." "SUCCESS"
        return $true
    }

    Write-Log "Failed to remove the scheduled task (exit code $LASTEXITCODE)." "ERROR"
    return $false
}

# Shows a Windows notification (balloon tip) so users notice
# maintenance runs that happen in the background via the
# scheduled task while the GUI is closed.
function Send-PCToast
{
    param(
        [string]$Title = "PC Doctor Portable",
        [string]$Message = "Maintenance completed."
    )

    try
    {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $IconPath = Join-Path $PSScriptRoot "..\Assets\PCDoctor.ico"

        $Icon = if (Test-Path $IconPath)
        {
            New-Object System.Drawing.Icon($IconPath)
        }
        else
        {
            [System.Drawing.SystemIcons]::Information
        }

        $Notify = New-Object System.Windows.Forms.NotifyIcon
        $Notify.Icon = $Icon
        $Notify.Visible = $true
        $Notify.BalloonTipTitle = $Title
        $Notify.BalloonTipText = $Message
        $Notify.ShowBalloonTip(10000)

        # Keep the (hidden) process alive until the balloon is gone
        Start-Sleep 12

        $Notify.Dispose()
    }
    catch {}
}
