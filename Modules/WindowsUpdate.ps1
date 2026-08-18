# ==========================================================
# PC Doctor Portable
# Windows Update Module v1.1
# Code Knot Technology
# ==========================================================
# Uses the official Windows Update Agent (COM) so updates
# are actually scanned, downloaded and installed - not just
# triggered asynchronously like the old UsoClient calls.
# Falls back to UsoClient if the COM API is unavailable.
# ==========================================================

$Global:LastModuleStatus = "FAILED"

Write-Step (Get-UIText "StepWindowsUpdate")

if (-not $Global:Config.WindowsUpdate.Enabled)
{
    Write-Log "Windows Update is disabled in Config.json. Skipping." "WARNING"
    $Global:LastModuleStatus = "SKIPPED"
    return
}

if ($Global:SkipOnlineModules)
{
    $Global:LastModuleStatus = "SKIPPED"
    return
}

# ----------------------------------------------------------
# Try the official Windows Update Agent API
# ----------------------------------------------------------

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

        Write-Log "Scanning for available updates..." "INFO"

        $SearchResult = $Searcher.Search(
            "IsInstalled=0 and IsHidden=0 and Type='Software'"
        )

        $Updates = $SearchResult.Updates
        $Count   = $Updates.Count

        Write-Log ((Get-UIText "UpdatesFound") -f $Count) "INFO"

        if ($Count -eq 0)
        {
            Write-Log (Get-UIText "WindowsUpToDate") "SUCCESS"
            $Global:LastModuleStatus = "SUCCESS"

            if (Test-PendingReboot) { $Global:RestartRequired = $true }
            return
        }

        # Report what will be installed
        foreach ($Update in $Updates)
        {
            Write-Log ("  - {0}" -f $Update.Title) "INFO"
        }

        # --------------------------------------------------
        # Download
        # --------------------------------------------------

        $UpdateList = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($Update in $Updates) { [void]$UpdateList.Add($Update) }

        $Downloader = $Session.CreateUpdateDownloader()
        $Downloader.Updates = $UpdateList

        Write-Log "Downloading updates (this can take a while)..." "INFO"
        $DownloadResult = $Downloader.Download()
        $DownloadCode   = $DownloadResult.ResultCode

        # 2 = succeeded
        if ($DownloadCode -ne 2)
        {
            Write-Log "Update download did not complete (result code $DownloadCode)." "WARNING"
            $Global:LastModuleStatus = "WARNING"

            if (Test-PendingReboot) { $Global:RestartRequired = $true }
            return
        }

        Write-Log "Updates downloaded." "SUCCESS"

        # --------------------------------------------------
        # Install
        # --------------------------------------------------

        $Installer = $Session.CreateUpdateInstaller()
        $Installer.Updates     = $UpdateList
        $Installer.ForceQuiet  = $true

        Write-Log "Installing updates (this can take a while)..." "INFO"
        $InstallResult = $Installer.Install()
        $InstallCode   = $InstallResult.ResultCode

        # Result codes: 2 = succeeded, 3 = succeeded with errors,
        # 4 = failed, 5 = aborted
        switch ($InstallCode)
        {
            2 { Write-Log (Get-UIText "UpdatesInstalled") "SUCCESS" }
            3 { Write-Log "Updates installed, but some reported errors." "WARNING" }
            4 { Write-Log "Update installation failed." "ERROR" }
            5 { Write-Log "Update installation was aborted." "WARNING" }
            Default { Write-Log "Update installation finished (result code $InstallCode)." "INFO" }
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
            Write-Log "A restart will be required after updates." "WARNING"
        }
        else
        {
            Write-Log "No restart required at this stage." "SUCCESS"
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

    if (-not (Test-Path $UsoClient))
    {
        Write-Log "Windows Update Engine not found." "ERROR"
        $Global:LastModuleStatus = "WARNING"
        return
    }

    Write-Log "Starting Windows Update Scan..." "INFO"
    & $UsoClient StartScan

    Start-Sleep 10

    Write-Log "Downloading available updates..." "INFO"
    & $UsoClient StartDownload

    Start-Sleep 10

    Write-Log "Installing available updates..." "INFO"
    & $UsoClient StartInstall

    Write-Log "Windows Update process started successfully." "SUCCESS"
    $Global:LastModuleStatus = "SUCCESS"
}
catch
{
    Write-Log $_.Exception.Message "ERROR"
    $Global:LastModuleStatus = "FAILED"
}

if (Test-PendingReboot)
{
    $Global:RestartRequired = $true
    Write-Log "A restart will be required after updates." "WARNING"
}
else
{
    Write-Log "No restart required at this stage." "SUCCESS"
}
