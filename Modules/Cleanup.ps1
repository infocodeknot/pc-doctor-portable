# ==========================================================
# PC Doctor Portable
# Cleanup Module v1.1
# Code Knot Technology
# ==========================================================
# All cleanup targets are driven by Config.json > Cleanup.
# Every target is guarded, measures freed space where
# practical, and never fails the whole run on one error.
# ==========================================================

$Global:LastModuleStatus = "FAILED"

Write-Step (Get-UIText "StepCleanup")

$CleanConfig = $Global:Config.Cleanup

# Nothing enabled -> skip gracefully
$EnabledCount = @(
    $CleanConfig.CleanTemp,
    $CleanConfig.RunDiskCleanup,
    $CleanConfig.CleanCookies,
    $CleanConfig.CleanBrowserCache,
    $CleanConfig.CleanPrefetch,
    $CleanConfig.CleanCrashDumps,
    $CleanConfig.CleanWindowsUpdateCache
) | Where-Object { $_ }

if (-not $EnabledCount)
{
    Write-Log "No cleanup tasks are enabled in Config.json. Skipping." "WARNING"
    $Global:LastModuleStatus = "SKIPPED"
    return
}

# ----------------------------------------------------------
# Interactive Confirmation
# ----------------------------------------------------------

if ($Global:AppMode -eq "INTERACTIVE")
{
    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + (Get-UIText "CleanupConfirm")) -Color Yellow
    Write-UIBoxLine -Line ""
    Write-UIBoxLine -Line ("  " + (Get-UIText "ContinueYes")) -Color Green
    Write-UIBoxLine -Line ("  " + (Get-UIText "ContinueNo")) -Color Yellow
    Write-UIBoxBottom
    Write-Host ""

    $Choice = (Read-Host (Get-UIText "SelectPrompt")).ToUpper()

    if ($Choice -ne "Y")
    {
        Write-Log "Cleanup skipped by user." "WARNING"
        $Global:LastModuleStatus = "SKIPPED"
        return
    }
}

# ----------------------------------------------------------
# Helpers (module-local names to avoid collisions)
# ----------------------------------------------------------

function Clear-PathAndReport
{
    param(
        [string]$Label,
        [string]$Path
    )

    if (-not (Test-Path $Path))
    {
        Write-Log "$Label : path not found." "INFO"
        return 0
    }

    $Before = Get-PathSize $Path

    Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

    $After = Get-PathSize $Path
    $FreedMB = [math]::Round(($Before - $After) / 1MB, 2)

    if ($FreedMB -gt 0)
    {
        Write-Log "$Label : $FreedMB MB freed." "SUCCESS"
    }
    else
    {
        Write-Log "$Label : nothing removed (empty or files in use)." "INFO"
    }

    return $FreedMB
}

function Clear-PatternSet
{
    param(
        [string]$Label,
        [string[]]$Patterns
    )

    $Removed = 0

    foreach ($Pattern in $Patterns)
    {
        $Items = @(Get-ChildItem -Path $Pattern -Force -ErrorAction SilentlyContinue)

        if ($Items.Count -gt 0)
        {
            $Items | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            $Removed += $Items.Count
        }
    }

    if ($Removed -gt 0)
    {
        Write-Log "$Label : $Removed item(s) removed." "SUCCESS"
    }
    else
    {
        Write-Log "$Label : nothing to clean." "INFO"
    }
}

# ----------------------------------------------------------
# 1) Windows / user temporary files
# ----------------------------------------------------------

$TotalFreed = 0

if ($CleanConfig.CleanTemp)
{
    $TempFolders = @(
        "$env:TEMP",
        "$env:LOCALAPPDATA\Temp",
        "$env:WINDIR\Temp"
    )

    foreach ($Folder in $TempFolders)
    {
        $TotalFreed += (Clear-PathAndReport -Label "Temp: $Folder" -Path $Folder)
    }
}
else
{
    Write-Log "Temp cleanup is disabled in Config.json." "INFO"
}

# ----------------------------------------------------------
# 2) Browser cache + 3) cookies
# ----------------------------------------------------------

$Browsers = @(
    @{
        Name    = "Google Chrome"
        Process = "chrome"
        Cache   = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Code Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\*\GPUCache"
        )
        Cookies = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Network\Cookies*"
        )
    },
    @{
        Name    = "Microsoft Edge"
        Process = "msedge"
        Cache   = @(
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Code Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\GPUCache"
        )
        Cookies = @(
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Network\Cookies*"
        )
    },
    @{
        Name    = "Mozilla Firefox"
        Process = "firefox"
        Cache   = @(
            "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2",
            "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\startupCache"
        )
        Cookies = @(
            "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cookies.sqlite*"
        )
    }
)

$CleanCookies       = [bool]$CleanConfig.CleanCookies
$CleanBrowserCache  = [bool]$CleanConfig.CleanBrowserCache

foreach ($Browser in $Browsers)
{
    if (Test-ProcessRunning -ProcessName $Browser.Process)
    {
        Write-UIStatusLine -Status "SKIPPED" -Message "$($Browser.Name) is running - cache/cookies left untouched"
        continue
    }

    if ($CleanBrowserCache)
    {
        Clear-PatternSet -Label "$($Browser.Name) cache" -Patterns $Browser.Cache
    }

    if ($CleanCookies)
    {
        Clear-PatternSet -Label "$($Browser.Name) cookies" -Patterns $Browser.Cookies
    }
}

if (-not $CleanCookies -and -not $CleanBrowserCache)
{
    Write-Log "Browser cache/cookies cleanup is disabled in Config.json." "INFO"
}

# ----------------------------------------------------------
# 4) Prefetch
# ----------------------------------------------------------

if ($CleanConfig.CleanPrefetch)
{
    Clear-PatternSet -Label "Prefetch" -Patterns @("$env:WINDIR\Prefetch\*.pf")
}
else
{
    Write-Log "Prefetch cleanup is disabled in Config.json." "INFO"
}

# ----------------------------------------------------------
# 5) Crash dumps
# ----------------------------------------------------------

if ($CleanConfig.CleanCrashDumps)
{
    Clear-PatternSet -Label "Crash dumps (Minidump)" -Patterns @("$env:WINDIR\Minidump\*")

    if (Test-Path "$env:WINDIR\MEMORY.DMP")
    {
        Remove-Item "$env:WINDIR\MEMORY.DMP" -Force -ErrorAction SilentlyContinue
        Write-Log "Memory dump (MEMORY.DMP) removed." "SUCCESS"
    }
}
else
{
    Write-Log "Crash dump cleanup is disabled in Config.json." "INFO"
}

# ----------------------------------------------------------
# 6) Disk Cleanup (cleanmgr)
# ----------------------------------------------------------

if ($CleanConfig.RunDiskCleanup)
{
    Write-Log "Running Disk Cleanup (cleanmgr)... " "INFO"

    try
    {
        $CleanMgr = Start-Process `
            -FilePath "$env:WINDIR\System32\cleanmgr.exe" `
            -ArgumentList "/autoclean" `
            -WindowStyle Hidden `
            -Wait `
            -PassThru

        Write-Log "Disk Cleanup finished (exit code $($CleanMgr.ExitCode))." "SUCCESS"
    }
    catch
    {
        Write-Log "Disk Cleanup could not be started." "WARNING"
    }
}
else
{
    Write-Log "Disk Cleanup is disabled in Config.json." "INFO"
}

# ----------------------------------------------------------
# 7) Windows Update cache (off by default - see Config.json)
# ----------------------------------------------------------

if ($CleanConfig.CleanWindowsUpdateCache)
{
    Write-Log "Clearing Windows Update cache..." "INFO"

    $ServicesStopped = $false

    try
    {
        Stop-Service -Name wuauserv, bits -Force -ErrorAction Stop
        $ServicesStopped = $true

        Remove-ItemContents "$env:WINDIR\SoftwareDistribution\Download"

        Write-Log "Windows Update cache cleared." "SUCCESS"
    }
    catch
    {
        Write-Log "Windows Update cache could not be cleared (services in use)." "WARNING"
    }
    finally
    {
        if ($ServicesStopped)
        {
            Start-Service -Name wuauserv, bits -ErrorAction SilentlyContinue
        }
    }
}
else
{
    Write-Log "Windows Update cache cleanup is disabled in Config.json." "INFO"
}

# ----------------------------------------------------------
# 8) Recycle Bin
# ----------------------------------------------------------

try
{
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Log "Recycle Bin cleaned." "SUCCESS"
}
catch
{
    Write-Log "Recycle Bin cleanup skipped (empty or unavailable)." "INFO"
}

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------

Write-Host ""
Write-UIBoxTop
if ($TotalFreed -gt 0)
{
    Write-UIBoxLine -Line ("  Cleanup Summary - approximately " + $TotalFreed + " MB freed") -Color Green
}
else
{
    Write-UIBoxLine -Line "  Cleanup Summary - nothing significant to free" -Color Green
}
Write-UIBoxBottom
Write-Host ""

Write-LogFile -Message ((Get-UIText "CleanupCompleted") + " (" + $TotalFreed + " MB freed).") -Level "SUCCESS"

$Global:LastModuleStatus = "SUCCESS"
