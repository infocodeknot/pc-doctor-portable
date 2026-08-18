# ==========================================================
# PC Doctor Portable
# Banner Module v1.1
# Code Knot Technology
# ==========================================================

function Show-Banner
{
    # Compact (Fluent-style) header: a single-line branded title
    # instead of the ASCII-art banner - set via Config.json
    # General.ConsoleStyle = "Compact".
    $Style = "Classic"

    if ($Global:Config -and $Global:Config.General -and $Global:Config.General.ConsoleStyle)
    {
        $Style = [string]$Global:Config.General.ConsoleStyle
    }

    if ($Style -eq "Compact")
    {
        Write-Host ""
        Write-Host "  " -NoNewline
        Write-Host "PC Doctor Portable" -ForegroundColor Cyan -NoNewline
        Write-Host ("  v" + $Global:Config.General.Version) -ForegroundColor Yellow -NoNewline
        Write-Host "   Windows Maintenance & Repair Tool" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    $BannerFile = Join-Path $PSScriptRoot "..\Assets\Banner.txt"

    Write-Host ""

    if (Test-Path $BannerFile)
    {
        Get-Content $BannerFile | ForEach-Object {
            Write-Host $_ -ForegroundColor Cyan
        }
    }
    else
    {
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "          PC Doctor Portable" -ForegroundColor Yellow
        Write-Host "          Windows Maintenance Tool" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan
    }

    Write-Host ""
}
