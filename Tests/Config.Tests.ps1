# ==========================================================
# Config.Tests.ps1 - Config.json validity and required keys
# (assertions kept compatible with Pester 3.4 and 5.x)
# ==========================================================

. (Join-Path $PSScriptRoot "_Bootstrap.ps1")

Describe "Config.json" {

    It "loads as valid JSON" {
        $Global:Config | Should Not Be $null
    }

    It "reports the current toolkit version" {
        $Global:Config.General.Version | Should Match "^\d+\.\d+"
    }

    It "has a supported language (EN or HI)" {
        (@("EN", "HI") -contains $Global:Config.General.Language) | Should Be $true
    }

    It "has a supported console style (Classic or Compact)" {
        (@("Classic", "Compact") -contains $Global:Config.General.ConsoleStyle) | Should Be $true
    }

    It "has a GitHub update URL" {
        $Global:Config.General.UpdateUrl | Should Match "github\.com"
    }

    It "defines every required section" {
        $Sections = @("General","RestorePoint","Cleanup","Optimization",
                      "WindowsUpdate","Drivers","Winget","Store",
                      "Repair","Restart","Retention")

        foreach ($Section in $Sections)
        {
            ($Global:Config.PSObject.Properties.Name -contains $Section) | Should Be $true
        }
    }

    It "uses booleans for all toggle settings" {
        $Booleans = @(
            "General.AutoMode",
            "General.ShowToast",
            "RestorePoint.Enabled",
            "Cleanup.CleanTemp",
            "Cleanup.RunDiskCleanup",
            "Cleanup.CleanCookies",
            "Cleanup.CleanBrowserCache",
            "Cleanup.CleanPrefetch",
            "Cleanup.CleanCrashDumps",
            "Cleanup.CleanWindowsUpdateCache",
            "Optimization.OptimizeDrives",
            "Optimization.RestartExplorer",
            "Optimization.ClearThumbnailCache",
            "WindowsUpdate.Enabled",
            "Drivers.Enabled",
            "Winget.Enabled",
            "Store.Enabled",
            "Repair.RunDISM",
            "Repair.RunSFC",
            "Restart.AutoRestart"
        )

        foreach ($Key in $Booleans)
        {
            $Section, $Name = $Key -split "\.", 2
            $IsBool = ($Global:Config.$Section.$Name -is [bool])
            $IsBool | Should Be True
        }
    }

    It "uses positive integers for retention settings" {
        $Retention = $Global:Config.Retention

        ($Retention.KeepLogs    -gt 0) | Should Be True
        ($Retention.KeepReports -gt 0) | Should Be True
        ($Retention.KeepBackups -gt 0) | Should Be True
    }
}
