# ==========================================================
# Update.Tests.ps1 - version parsing + update check logic
# Network paths are tested only against an unreachable local
# address so the suite is deterministic and offline-safe.
# ==========================================================

. (Join-Path $PSScriptRoot "_Bootstrap.ps1")

Describe "ConvertTo-ComparableVersion" {

    It "parses a plain semver tag" {
        (ConvertTo-ComparableVersion -Tag "v1.2.0").ToString() | Should Be "1.2.0"
    }

    It "parses a two-part tag as x.y.0" {
        (ConvertTo-ComparableVersion -Tag "1.2").ToString() | Should Be "1.2.0"
    }

    It "parses underscore tags (is-7_1_0 style)" {
        (ConvertTo-ComparableVersion -Tag "is-7_1_0").ToString() | Should Be "7.1.0"
    }

    It "parses a version embedded in a longer tag" {
        (ConvertTo-ComparableVersion -Tag "release-2024.1.2-beta").ToString() | Should Be "2024.1.2"
    }

    It "returns null for tags without a version" {
        (ConvertTo-ComparableVersion -Tag "not-a-version") | Should Be $null
    }

    It "returns null for empty input" {
        (ConvertTo-ComparableVersion -Tag "") | Should Be $null
    }

    It "orders versions correctly" {
        $A = ConvertTo-ComparableVersion -Tag "v1.2.0"
        $B = ConvertTo-ComparableVersion -Tag "v1.2.1"
        $C = ConvertTo-ComparableVersion -Tag "v2.0"

        ($A -lt $B) | Should Be True
        ($B -lt $C) | Should Be True
        ($A -lt $C) | Should Be True
    }
}

Describe "Test-AppUpdate (offline-safe)" {

    It "does nothing when the update URL is empty" {
        { Test-AppUpdate -UpdateUrl "" -CurrentVersion "1.2" } | Should Not Throw
    }

    It "returns false quietly when the check is unavailable" {
        $Result = Test-AppUpdate `
            -UpdateUrl "http://127.0.0.1:1/releases/latest" `
            -CurrentVersion "1.2" -Quiet

        $Result | Should Be $false
    }
}

Describe "Get-AppUpdateInfo (offline-safe)" {

    It "returns Newer = null when the endpoint is unreachable" {
        $Info = Get-AppUpdateInfo -UpdateUrl "http://127.0.0.1:1/releases/latest" -CurrentVersion "1.2"

        $Info.Newer | Should Be $null
    }
}
