# ==========================================================
# Modules.Tests.ps1 - module contract enforcement
#
# Guards the audit fixes: every module must parse, must set
# $Global:LastModuleStatus, and every Config key it reads
# must exist in Config.json (so a typo'd setting silently
# disables nothing - it fails the test instead).
# ==========================================================

. (Join-Path $PSScriptRoot "_Bootstrap.ps1")

$ModuleFiles = @(
    "Internet.ps1", "Restore.ps1", "WindowsUpdate.ps1", "Drivers.ps1",
    "Winget.ps1", "Store.ps1", "Repair.ps1", "Cleanup.ps1",
    "Optimize.ps1", "Verification.ps1", "Report.ps1", "Restart.ps1"
)

Describe "Module syntax" {

    It "parses every module with zero errors" {
        foreach ($File in $ModuleFiles)
        {
            $Tokens = $null
            $Errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                (Join-Path $Global:TestModules $File), [ref]$Tokens, [ref]$Errors)

            if ($Errors.Count -gt 0)
            {
                throw "$File has $($Errors.Count) syntax error(s): $($Errors[0].Message)"
            }
        }
    }
}

Describe "Module status contract" {

    It "every module defaults LastModuleStatus to FAILED" {
        foreach ($File in $ModuleFiles)
        {
            $Content = Get-Content (Join-Path $Global:TestModules $File) -Raw

            if ($Content -notmatch '\$Global:LastModuleStatus\s*=\s*"FAILED"')
            {
                throw "$File does not initialize `$Global:LastModuleStatus"
            }
        }
    }

    It "every module has a header comment" {
        foreach ($File in $ModuleFiles)
        {
            $FirstLine = (Get-Content (Join-Path $Global:TestModules $File) | Where-Object { $_.Trim() } | Select-Object -First 1)

            if ($FirstLine -notmatch '^\s*#')
            {
                throw "$File has no header comment"
            }
        }
    }
}

Describe "Config wiring (no orphan or missing settings)" {

    $AliasMap = @{
        "CleanConfig"    = "Cleanup"
        "OptimizeConfig" = "Optimization"
        "RepairConfig"   = "Repair"
    }

    It "every config reference resolves in Config.json" {
        foreach ($File in $ModuleFiles)
        {
            $Content = Get-Content (Join-Path $Global:TestModules $File) -Raw

            # $Global:Config.Section.Key
            $Matches = [regex]::Matches($Content, '\$Global:Config\.([A-Za-z]+)\.([A-Za-z]+)')

            foreach ($M in $Matches)
            {
                $Section = $M.Groups[1].Value
                $Key     = $M.Groups[2].Value

                if (-not $Global:Config.$Section -or -not ($Global:Config.$Section.PSObject.Properties.Name -contains $Key))
                {
                    throw "$File reads Config.$Section.$Key which does not exist in Config.json"
                }
            }

            # Module-local aliases: $CleanConfig.Key -> Cleanup.Key
            foreach ($Alias in $AliasMap.Keys)
            {
                $AliasMatches = [regex]::Matches($Content, ('\${0}\.([A-Za-z]+)' -f $Alias))

                foreach ($M in $AliasMatches)
                {
                    $Key = $M.Groups[1].Value
                    $Section = $AliasMap[$Alias]

                    if (-not $Global:Config.$Section -or -not ($Global:Config.$Section.PSObject.Properties.Name -contains $Key))
                    {
                        throw "$File reads ${Alias}.$Key (Config.$Section.$Key) which does not exist in Config.json"
                    }
                }
            }
        }
    }

    It "every cleanup toggle is referenced by the module" {
        $CleanupText = Get-Content (Join-Path $Global:TestModules "Cleanup.ps1") -Raw

        foreach ($Key in @("CleanTemp","RunDiskCleanup","CleanCookies","CleanBrowserCache",
                           "CleanPrefetch","CleanCrashDumps","CleanWindowsUpdateCache"))
        {
            if ($CleanupText -notmatch ('\$CleanConfig\.{0}' -f $Key))
            {
                throw "Cleanup.ps1 never references CleanConfig.$Key"
            }
        }

        ($CleanupText -match "EnabledCount") | Should Be $true
    }
}

Describe "Main.ps1 run order" {

    It "references every module file that exists on disk" {
        $MainText = Get-Content (Join-Path $Global:TestRoot "Main.ps1") -Raw
        $Refs = [regex]::Matches($MainText, 'Run-Module\s+"[^"]+"\s+"([^"]+\.ps1)"')

        ($Refs.Count -ge 12) | Should Be True

        foreach ($M in $Refs)
        {
            $File = $M.Groups[1].Value
            (Test-Path (Join-Path $Global:TestModules $File)) | Should Be $true
        }
    }

    It "loads every core module in the header" {
        $MainText = Get-Content (Join-Path $Global:TestRoot "Main.ps1") -Raw
        $Core = @("Logger.ps1","UI.ps1","Common.ps1","Update.ps1","TaskScheduler.ps1","Banner.ps1","Startup.ps1","Menu.ps1")

        foreach ($File in $Core)
        {
            ($MainText -match ('Join-Path \$Modules "{0}"' -f $File)) | Should Be $true
        }
    }
}
