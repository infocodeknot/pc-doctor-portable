# ==========================================================
# PC Doctor Portable
# Internet Module v1.1
# Code Knot Technology
# ==========================================================

$Global:LastModuleStatus = "FAILED"

Write-Step (Get-UIText "StepInternet")

function Test-Internet
{
    # ICMP probe (some networks block ping - this is only one signal)
    $PingOk = $false
    try
    {
        $PingOk = Test-Connection -ComputerName "1.1.1.1" -Count 1 -Quiet -ErrorAction Stop
    }
    catch {}

    # DNS + HTTPS probe against Microsoft's connectivity test host
    $HttpOk = $false
    try
    {
        $HttpOk = [bool](Test-NetConnection `
            -ComputerName "www.msftconnecttest.com" `
            -Port 443 `
            -InformationLevel Quiet `
            -WarningAction SilentlyContinue)
    }
    catch {}

    return ($PingOk -or $HttpOk)
}

if (Test-Internet)
{
    Write-Log (Get-UIText "InternetConnected") "SUCCESS"
    $Global:LastModuleStatus = "SUCCESS"
    return
}

Write-Log (Get-UIText "InternetNotAvailable") "WARNING"

# -------------------------------
# AUTO MODE
# -------------------------------
if ($Global:AppMode -eq "AUTO")
{
    Write-Log "Attempting Automatic Network Repair..." "INFO"

    $RepairSteps = @(
        @{ Name = "DNS Cache";     Command = { ipconfig /flushdns | Out-Null } },
        @{ Name = "Winsock Catalog"; Command = { netsh winsock reset | Out-Null } },
        @{ Name = "TCP/IP Stack";  Command = { netsh int ip reset | Out-Null } }
    )

    foreach ($Step in $RepairSteps)
    {
        try
        {
            & $Step.Command

            if ($LASTEXITCODE -eq 0)
            {
                Write-Log "$($Step.Name) repaired." "SUCCESS"
            }
            else
            {
                Write-Log "$($Step.Name) repair failed (exit code $LASTEXITCODE)." "WARNING"
            }
        }
        catch
        {
            Write-Log "$($Step.Name) repair could not run." "WARNING"
        }
    }

    Start-Sleep 5

    if (Test-Internet)
    {
        Write-Log "Internet Restored." "SUCCESS"
        $Global:LastModuleStatus = "SUCCESS"
        return
    }

    Write-Log "Internet still unavailable." "WARNING"
    Write-Log "Online modules will be skipped." "WARNING"

    $Global:SkipOnlineModules = $true
    $Global:LastModuleStatus = "WARNING"

    return
}

# -------------------------------
# INTERACTIVE MODE
# -------------------------------

do
{
    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + (Get-UIText "InternetRequired")) -Color Yellow
    Write-UIBoxLine -Line ""
    Write-UIBoxLine -Line ("  " + (Get-UIText "RetryOpt")) -Color Green
    Write-UIBoxLine -Line ("  " + (Get-UIText "SkipOnlineOpt")) -Color Yellow
    Write-UIBoxLine -Line ("  " + (Get-UIText "ExitOpt")) -Color Red
    Write-UIBoxBottom
    Write-Host ""

    $Choice = (Read-Host (Get-UIText "SelectPrompt")).ToUpper()

    switch ($Choice)
    {
        "R"
        {
            if (Test-Internet)
            {
                Write-Log "Internet Connected." "SUCCESS"
                $Global:LastModuleStatus = "SUCCESS"
                return
            }

            Write-Log "Internet Still Not Available." "WARNING"
        }

        "S"
        {
            Write-Log "Online Modules Skipped by User." "WARNING"
            $Global:SkipOnlineModules = $true
            $Global:LastModuleStatus = "WARNING"
            return
        }

        "E"
        {
            $Global:AppExit = $true
            return
        }
    }
} while ($true)
