# ==========================================================
# Core.Tests.ps1 - shared utilities from Common.ps1 / UI.ps1
# All tests are safe: only pure functions and temp folders.
# ==========================================================

. (Join-Path $PSScriptRoot "_Bootstrap.ps1")

Describe "Core module loading" {

    It "exposes every required function" {
        $Required = @(
            "Run-Module", "Write-Step", "Test-Admin", "Get-UIText",
            "Test-ProcessRunning", "Get-PathSize", "Remove-ItemContents",
            "Test-PendingReboot", "Enforce-Retention", "Load-Config",
            "Write-Log", "Write-LogFile", "Close-Logger",
            "Show-Banner", "Show-Startup", "Show-Menu",
            "Get-ModuleDisplayName", "Test-AppUpdate", "Get-AppUpdateInfo",
            "Write-UIBoxTop", "Write-UIBoxLine", "Write-UIBoxBottom",
            "Get-UIStatusChip", "Get-UIStatusColor", "Write-UIStatusLine",
            "Write-UIModuleStart", "Write-UIModuleEnd", "Write-UIProgressBar",
            "Show-UISpinner", "Set-ConsoleIcon"
        )

        foreach ($Name in $Required)
        {
            (Get-Command $Name -ErrorAction SilentlyContinue) | Should Not Be $null
        }
    }
}

Describe "UI status chips" {

    It "maps every status to the right chip" {
        (Get-UIStatusChip "SUCCESS") | Should Be "[ OK ]"
        (Get-UIStatusChip "FAILED")  | Should Be "[FAIL]"
        (Get-UIStatusChip "WARNING") | Should Be "[WARN]"
        (Get-UIStatusChip "SKIPPED") | Should Be "[SKIP]"
        (Get-UIStatusChip "MISSING") | Should Be "[MISS]"
    }

    It "maps every status to a console color" {
        (Get-UIStatusColor "SUCCESS") | Should Be "Green"
        (Get-UIStatusColor "FAILED")  | Should Be "Red"
        (Get-UIStatusColor "WARNING") | Should Be "Yellow"
        (Get-UIStatusColor "SKIPPED") | Should Be "DarkGray"
    }

    It "is case-insensitive" {
        (Get-UIStatusChip "success") | Should Be "[ OK ]"
        (Get-UIStatusChip "Failed")  | Should Be "[FAIL]"
    }
}

Describe "Localization (Get-UIText)" {

    It "returns the English string for EN" {
        $Old = $Global:Config.General.Language
        $Global:Config.General.Language = "EN"
        (Get-UIText "Start") | Should Be "Start"
        $Global:Config.General.Language = $Old
    }

    It "returns the Hindi string for HI" {
        $Old = $Global:Config.General.Language
        $Global:Config.General.Language = "HI"
        $Hindi = Get-UIText "Start"
        $Global:Config.General.Language = $Old

        ($Hindi -ne "Start") | Should Be True
        ($Hindi -match "[^\x00-\x7F]") | Should Be True   # contains non-ASCII Devanagari
    }

    It "falls back to the key when missing" {
        (Get-UIText "NoSuchKeyExists") | Should Be "NoSuchKeyExists"
    }

    It "translates module display names" {
        $Old = $Global:Config.General.Language
        $Global:Config.General.Language = "HI"

        $Name = Get-ModuleDisplayName -Name "Windows Update"

        $Global:Config.General.Language = $Old

        ($Name -ne "Windows Update") | Should Be True
    }
}

Describe "File helpers" {

    It "Get-PathSize sums file sizes recursively" {
        $Dir = Join-Path $TestDrive "size"
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        Set-Content -Path (Join-Path $Dir "a.txt") -Value ("X" * 100) -Encoding UTF8
        Set-Content -Path (Join-Path $Dir "b.txt") -Value ("Y" * 50)  -Encoding UTF8

        (Get-PathSize $Dir) | Should BeGreaterThan 100
    }

    It "Remove-ItemContents empties a directory" {
        $Dir = Join-Path $TestDrive "wipe"
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Dir "sub") -Force | Out-Null
        Set-Content -Path (Join-Path $Dir "a.txt") -Value "x" -Encoding UTF8

        Remove-ItemContents -Path $Dir

        (Get-ChildItem $Dir -Force).Count | Should Be 0
    }

    It "Get-PathSize returns 0 for missing paths" {
        (Get-PathSize (Join-Path $TestDrive "does-not-exist")) | Should Be 0
    }
}

Describe "Retention (Enforce-Retention)" {

    It "deletes the oldest files beyond the keep limit" {
        $Dir = Join-Path $TestDrive "keep"
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null

        foreach ($I in 1..5)
        {
            $F = Join-Path $Dir ("file{0}.txt" -f $I)
            Set-Content -Path $F -Value $I -Encoding UTF8
            (Get-Item $F).LastWriteTime = (Get-Date).AddHours(-$I)
        }

        Enforce-Retention -Folder $Dir -Keep 3

        (Get-ChildItem $Dir -File).Count | Should Be 3
    }

    It "keeps everything when under the limit" {
        $Dir = Join-Path $TestDrive "keep2"
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        Set-Content -Path (Join-Path $Dir "only.txt") -Value "x" -Encoding UTF8

        Enforce-Retention -Folder $Dir -Keep 10

        (Get-ChildItem $Dir -File).Count | Should Be 1
    }

    It "does nothing for a missing folder" {
        { Enforce-Retention -Folder (Join-Path $TestDrive "nope") -Keep 3 } | Should Not Throw
    }
}

Describe "Process checks" {

    It "Test-PendingReboot always returns a boolean" {
        (Test-PendingReboot -is [bool]) | Should Be True
    }

    It "Test-ProcessRunning finds a real process and misses a fake one" {
        (Test-ProcessRunning -ProcessName @("powershell")) | Should Be True
        (Test-ProcessRunning -ProcessName @("definitely-not-a-process-xyz")) | Should Be False
    }
}
