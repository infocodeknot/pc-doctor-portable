# ==========================================================
# PC Doctor Portable
# Update Module v1.1
# Code Knot Technology
# ==========================================================
# Checks the configured GitHub releases API for a newer
# version. Fails gracefully when offline, when the URL is
# missing, or when the repository does not exist yet.
# ==========================================================

function Test-AppUpdate
{
    param(
        [string]$UpdateUrl,
        [string]$CurrentVersion,
        [switch]$Quiet
    )

    if (-not $UpdateUrl)
    {
        if (-not $Quiet) { Write-Log "Update check is disabled (no UpdateUrl in Config.json)." "INFO" }
        return
    }

    Write-Log "Checking for updates..." "INFO"

    $Result = Get-AppUpdateInfo -UpdateUrl $UpdateUrl -CurrentVersion $CurrentVersion

    if ($Result.Newer)
    {
        Write-Log "New version available : v$($Result.Version)" "SUCCESS"
        Write-Log "Download              : $($Result.Url)" "SUCCESS"
        return $true
    }
    elseif ($null -eq $Result.Newer)
    {
        Write-Log "Update check unavailable (offline or repository not found)." "WARNING"
        return $false
    }
    else
    {
        Write-Log "You are up to date (v$($Result.Version))." "SUCCESS"
        return $false
    }
}

# Parses release tags into a comparable [version]. Handles
# "v1.2.0", "1.2", "is-7_1_0", "release-2024.1.2-beta" etc.
# Returns $null when no version can be extracted.
function ConvertTo-ComparableVersion
{
    param([string]$Tag)

    if (-not $Tag) { return $null }

    $Match = [regex]::Match(($Tag -replace "^[vV]", ""), "\d+([._]\d+)*")

    if (-not $Match.Success) { return $null }

    $Parts = (($Match.Value) -replace "_", ".") -split "\."
    while ($Parts.Count -lt 3) { $Parts += "0" }

    try
    {
        return [version]($Parts -join ".")
    }
    catch
    {
        return $null
    }
}

# Returns @{ Newer = $true/$false/$null ; Version = 'x.y.z' ; Url = '...' }
function Get-AppUpdateInfo
{
    param(
        [string]$UpdateUrl,
        [string]$CurrentVersion
    )

    try
    {
        $Request = [System.Net.HttpWebRequest]::Create($UpdateUrl)
        $Request.Timeout   = 10000
        $Request.ReadWriteTimeout = 10000
        $Request.UserAgent = "PCDoctorPortable"

        $Response = $Request.GetResponse()

        $Reader = New-Object System.IO.StreamReader($Response.GetResponseStream())
        $Json   = $Reader.ReadToEnd()
        $Reader.Dispose()
        $Response.Dispose()

        $Release = $Json | ConvertFrom-Json

        # Tag can be "v1.2.0", "1.2", "is-7_1_0", etc
        $LatestVer = ConvertTo-ComparableVersion -Tag $Release.tag_name
        $LatestVersion = if ($LatestVer) { $LatestVer.ToString() } else { "" }

        if (-not $LatestVer)
        {
            return @{ Newer = $false; Version = $Release.tag_name; Url = $Release.html_url }
        }

        try
        {
            $CurrentVer = ConvertTo-ComparableVersion -Tag $CurrentVersion

            if ($CurrentVer -and $LatestVer -gt $CurrentVer)
            {
                return @{ Newer = $true;  Version = $LatestVersion; Url = $Release.html_url }
            }
        }
        catch {}

        return @{ Newer = $false; Version = $LatestVersion; Url = $Release.html_url }
    }
    catch
    {
        return @{ Newer = $null; Version = ""; Url = "" }
    }
}
