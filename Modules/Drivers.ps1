# ==========================================================
# PC Doctor Portable
# Drivers Module v1.1
# Code Knot Technology
# ==========================================================
# Driver updates come through the Windows Update pipeline.
# Uses the WUAgent COM API (Type='Driver') so drivers are
# really installed, with UsoClient as a fallback.
# ==========================================================

$Global:LastModuleStatus = "FAILED"

Write-Step (Get-UIText "StepDrivers")

if (-not $Global:Config.Drivers.Enabled)
{
    Write-Log "Driver updates are disabled in Config.json. Skipping." "WARNING"
    $Global:LastModuleStatus = "SKIPPED"
    return
}

if ($Global:SkipOnlineModules)
{
    $Global:LastModuleStatus = "SKIPPED"
    return
}

$Session = $null

try
{
    $Session = New-Object -ComObject Microsoft.Update.Session
}
catch
{
    $Session = $null
}

if ($Session)
{
    try
    {
        $Searcher = $Session.CreateUpdateSearcher()

        Write-Log "Searching for Driver Updates..." "INFO"

        $SearchResult = $Searcher.Search(
            "IsInstalled=0 and IsHidden=0 and Type='Driver'"
        )

        $Updates = $SearchResult.Updates
        $Count   = $Updates.Count

        Write-Log "Found $Count available driver update(s)." "INFO"

        if ($Count -eq 0)
        {
            Write-Log (Get-UIText "DriversUpToDate") "SUCCESS"
            $Global:LastModuleStatus = "SUCCESS"

            if (Test-PendingReboot) { $Global:RestartRequired = $true }
            return
        }

        foreach ($Update in $Updates)
        {
            Write-Log ("  - {0}" -f $Update.Title) "INFO"
        }

        $UpdateList = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($Update in $Updates) { [void]$UpdateList.Add($Update) }

        $Downloader = $Session.CreateUpdateDownloader()
        $Downloader.Updates = $UpdateList

        Write-Log "Downloading driver updates..." "INFO"
        $DownloadResult = $Downloader.Download()

        if ($DownloadResult.ResultCode -ne 2)
        {
            Write-Log "Driver download did not complete (result code $($DownloadResult.ResultCode))." "WARNING"
            $Global:LastModuleStatus = "WARNING"

            if (Test-PendingReboot) { $Global:RestartRequired = $true }
            return
        }

        Write-Log "Drivers downloaded." "SUCCESS"

        $Installer = $Session.CreateUpdateInstaller()
        $Installer.Updates    = $UpdateList
        $Installer.ForceQuiet = $true

        Write-Log "Installing driver updates..." "INFO"
        $InstallResult = $Installer.Install()
        $InstallCode   = $InstallResult.ResultCode

        switch ($InstallCode)
        {
            2 { Write-Log "All drivers installed successfully." "SUCCESS" }
            3 { Write-Log "Drivers installed, but some reported errors." "WARNING" }
            4 { Write-Log "Driver installation failed." "ERROR" }
            5 { Write-Log "Driver installation was aborted." "WARNING" }
            Default { Write-Log "Driver installation finished (result code $InstallCode)." "INFO" }
        }

        if ($InstallCode -in 2, 3)
        {
            $Global:LastModuleStatus = "SUCCESS"
        }
        else
        {
            $Global:LastModuleStatus = "WARNING"
        }

        if (Test-PendingReboot)
        {
            $Global:RestartRequired = $true
            Write-Log "A restart will be required after driver updates." "WARNING"
        }

        return
    }
    catch
    {
        Write-Log "Windows Update Agent failed : $($_.Exception.Message)" "WARNING"
        Write-Log "Falling back to UsoClient..." "INFO"
    }
}

# ----------------------------------------------------------
# Fallback : UsoClient
# ----------------------------------------------------------

try
{
    $UsoClient = Join-Path $env:SystemRoot "System32\UsoClient.exe"

    if (Test-Path $UsoClient)
    {
        Write-Log "Searching for Driver Updates..." "INFO"

        & $UsoClient StartScan
        Start-Sleep 5

        & $UsoClient StartDownload
        Start-Sleep 5

        & $UsoClient StartInstall

        Write-Log "Driver Update Process Started." "SUCCESS"
        $Global:LastModuleStatus = "SUCCESS"
    }
    else
    {
        Write-Log "Windows Driver Update Engine Not Found." "WARNING"
        $Global:LastModuleStatus = "WARNING"
    }
}
catch
{
    Write-Log $_.Exception.Message "ERROR"
    $Global:LastModuleStatus = "FAILED"
}

if (Test-PendingReboot)
{
    $Global:RestartRequired = $true
    Write-Log "A restart will be required after driver updates." "WARNING"
}
