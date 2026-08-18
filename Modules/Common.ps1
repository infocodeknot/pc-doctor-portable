# ==========================================================
# PC Doctor Portable
# Common Module v1.1
# Code Knot Technology
# ==========================================================
# Single module runner + shared utilities. The console is
# rendered by Modules\UI.ps1 (boxed frames, chips, bars);
# the log file gets plain lines from Write-LogFile.
# ==========================================================

$Global:ModuleResults = @()

# Localized display name for a module (Config language)
function Get-ModuleDisplayName
{
    param([string]$Name)

    $KeyMap = @{
        "Internet Check"  = "ModuleInternet"
        "Restore Point"   = "ModuleRestorePoint"
        "Windows Update"  = "ModuleWindowsUpdate"
        "Driver Update"   = "ModuleDrivers"
        "Software Update" = "ModuleSoftware"
        "Microsoft Store" = "ModuleStore"
        "Windows Repair"  = "ModuleRepair"
        "Cleanup"         = "ModuleCleanup"
        "Optimization"    = "ModuleOptimization"
        "Verification"    = "ModuleVerification"
        "Report"          = "ModuleReport"
        "Restart Manager" = "ModuleRestart"
    }

    if ($KeyMap.ContainsKey($Name))
    {
        $Text = Get-UIText $KeyMap[$Name]
        if ($Text -and $Text -ne $KeyMap[$Name]) { return $Text }
    }

    return $Name
}

function Run-Module
{
    param(
        [string]$Name,
        [string]$File
    )

    $Display = Get-ModuleDisplayName -Name $Name

    $Index = $Global:ModuleResults.Count + 1
    $Total = if ($Global:TotalModules) { $Global:TotalModules } else { 0 }

    Write-LogFile -Message "=================================================="
    Write-LogFile -Message "Running : $Display"
    Write-LogFile -Message "=================================================="

    Write-UIModuleStart -Name $Display -Index $Index -Total $Total

    $ModulePath = Join-Path $PSScriptRoot $File

    # Skip online modules when the internet is unavailable
    if ($Global:SkipOnlineModules)
    {
        $OnlineModules = @(
            "WindowsUpdate.ps1",
            "Drivers.ps1",
            "Winget.ps1",
            "Store.ps1"
        )

        if ($File -in $OnlineModules)
        {
            Write-LogFile -Message ((Get-UIText "OnlineSkipped") -f $Display) -Level "WARNING"
            Write-UIModuleEnd -Name $Display -Status "SKIPPED" -Duration "-"

            $Global:ModuleResults += [PSCustomObject]@{
                Module   = $Name
                Status   = "SKIPPED"
                Duration = "-"
            }

            return
        }
    }

    if (-not (Test-Path $ModulePath))
    {
        Write-LogFile -Message "$File Not Found." -Level "ERROR"
        Write-UIModuleEnd -Name $Display -Status "MISSING" -Duration "-"

        $Global:ModuleResults += [PSCustomObject]@{
            Module   = $Name
            Status   = "MISSING"
            Duration = "-"
        }

        return
    }

    $Start = Get-Date

    try
    {
        # Each module reports its own result via $Global:LastModuleStatus
        $Global:LastModuleStatus = "SUCCESS"
        . $ModulePath

        if ($Global:LastModuleStatus -notin @("SUCCESS","FAILED","SKIPPED","WARNING"))
        {
            $Global:LastModuleStatus = "SUCCESS"
        }

        $Seconds   = [math]::Round(((Get-Date) - $Start).TotalSeconds, 0)
        $Minutes   = [math]::Floor($Seconds / 60)
        $Remainder = $Seconds % 60
        $Duration  = "{0:00}:{1:00}" -f $Minutes, $Remainder

        $Global:ModuleResults += [PSCustomObject]@{
            Module   = $Name
            Status   = $Global:LastModuleStatus
            Duration = $Duration
        }

        # Machine-readable result line - the GUI parses this to
        # update module status chips live.
        $ResultLevel = switch ($Global:LastModuleStatus)
        {
            "SUCCESS" { "SUCCESS" }
            "FAILED"  { "ERROR" }
            "WARNING" { "WARNING" }
            "SKIPPED" { "WARNING" }
            Default   { "INFO" }
        }

        Write-LogFile -Message ("Result : {0} : {1} : {2}" -f $Display, $Global:LastModuleStatus, $Duration) -Level $ResultLevel
        Write-LogFile -Message "$Display Completed."
        Write-UIModuleEnd -Name $Display -Status $Global:LastModuleStatus -Duration $Duration
    }
    catch
    {
        Write-LogFile -Message "ERROR : $($_.Exception.Message)" -Level "ERROR"
        Write-UIModuleEnd -Name $Display -Status "FAILED" -Duration "-"

        $Global:ModuleResults += [PSCustomObject]@{
            Module   = $Name
            Status   = "FAILED"
            Duration = "-"
        }
    }
}

function Write-Step
{
    param(
        [string]$Message
    )

    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + $Message) -Color Cyan
    Write-UIBoxBottom

    Write-LogFile -Message $Message
}

function Test-Admin
{
    $Current = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )

    return $Current.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

# Localized UI text (Config.json > General > Language - EN or HI)
function Get-UIText
{
    param([string]$Key)

    try
    {
        $Lang = "EN"

        if ($Global:Config -and $Global:Config.General -and $Global:Config.General.Language)
        {
            $Lang = $Global:Config.General.Language
        }

        if ($Global:Strings -and $Global:Strings.$Lang -and $Global:Strings.$Lang.$Key)
        {
            return $Global:Strings.$Lang.$Key
        }

        if ($Global:Strings -and $Global:Strings.EN -and $Global:Strings.EN.$Key)
        {
            return $Global:Strings.EN.$Key
        }
    }
    catch {}

    return $Key
}

function Test-ProcessRunning
{
    param(
        [string[]]$ProcessName
    )

    foreach ($Name in $ProcessName)
    {
        if (Get-Process -Name $Name -ErrorAction SilentlyContinue)
        {
            return $true
        }
    }

    return $false
}

function Get-PathSize
{
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) { return 0 }

    $Total = 0

    Get-ChildItem -Path $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
        ForEach-Object { $Total += $_.Length }

    return $Total
}

function Remove-ItemContents
{
    param(
        [string]$Path
    )

    Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}

function Test-PendingReboot
{
    $Keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting"
    )

    foreach ($Key in $Keys)
    {
        if (Test-Path $Key) { return $true }
    }

    try
    {
        $SessionMgr = Get-ItemProperty `
            "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
            -ErrorAction SilentlyContinue

        if ($SessionMgr -and $SessionMgr.PendingFileRenameOperations)
        {
            return $true
        }
    }
    catch {}

    return $false
}

function Wait-Seconds
{
    param([int]$Seconds)

    for ($i = $Seconds; $i -ge 1; $i--)
    {
        $Percent = [int](100 * ($Seconds - $i + 1) / $Seconds)
        Write-UIProgressBar -Percent $Percent -Label ("Continuing in $i second(s)")
        Start-Sleep 1
    }

    Write-UIProgressBar -Percent 100 -Label "Continuing" -Complete
    Write-Host ""
}

function Enforce-Retention
{
    param(
        [string]$Folder,
        [int]$Keep
    )

    if ($Keep -le 0) { return }
    if (-not (Test-Path $Folder)) { return }

    Get-ChildItem -Path $Folder -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $Keep |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# ==========================================================
# Load Configuration
# ==========================================================

function Load-Config
{
    param(
        [string]$ConfigPath = ""
    )

    # The GUI writes its settings to %APPDATA% and passes the
    # path here; the console uses the default app-dir file.
    if (-not $ConfigPath)
    {
        $ConfigPath = Join-Path $PSScriptRoot "..\Config.json"
    }

    if (-not (Test-Path $ConfigPath))
    {
        throw "Config.json not found."
    }

    try
    {
        $Global:Config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Write-LogFile -Message "Configuration Loaded." -Level "SUCCESS"
    }
    catch
    {
        throw "Unable to read Config.json : $($_.Exception.Message)"
    }

    # Load localized UI strings (EN/HI)
    $StringsPath = Join-Path $PSScriptRoot "..\App\strings.json"

    try
    {
        $Global:Strings = Get-Content $StringsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch
    {
        $Global:Strings = $null
    }

    # Enforce retention limits from the config
    try
    {
        $Keep = $Global:Config.Retention

        Enforce-Retention -Folder $Global:LogFolder -Keep ([int]$Keep.KeepLogs)
        Enforce-Retention -Folder (Join-Path $PSScriptRoot "..\Reports") -Keep ([int]$Keep.KeepReports)
        Enforce-Retention -Folder (Join-Path $PSScriptRoot "..\Backups") -Keep ([int]$Keep.KeepBackups)
    }
    catch {}
}
