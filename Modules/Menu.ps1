# ==========================================================
# PC Doctor Portable
# Menu Module v1.1
# Code Knot Technology
# ==========================================================

$Global:AppMode = "AUTO"

# Lists Logs\ and Reports\ newest-first (used by menu option 4
# and callable from the console)
function Show-HistoryList
{
    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + (Get-UIText "MenuHistoryTitle")) -Color Yellow
    Write-UIBoxBottom
    Write-Host ""

    $Root = Split-Path -Parent $PSScriptRoot
    $Entries = @()

    foreach ($Folder in @((Join-Path $Root "Logs"), (Join-Path $Root "Reports")))
    {
        if (Test-Path $Folder)
        {
            $Entries += Get-ChildItem $Folder -File -Filter *.txt -ErrorAction SilentlyContinue
        }
    }

    $Entries = @($Entries | Sort-Object LastWriteTime -Descending)

    if ($Entries.Count -eq 0)
    {
        Write-UIBoxLine -Line ("  " + (Get-UIText "MenuHistoryEmpty")) -Color DarkGray
        Write-Host ""
        return
    }

    foreach ($File in $Entries | Select-Object -First 20)
    {
        $Size = [math]::Round($File.Length / 1KB, 1)
        $Line = "  {0}   {1:yyyy-MM-dd HH:mm}   {2} KB" -f $File.Name, $File.LastWriteTime, $Size
        Write-UIBoxLine -Line $Line -Color Cyan
    }

    if ($Entries.Count -gt 20)
    {
        Write-UIBoxLine -Line ("  ... and {0} more" -f ($Entries.Count - 20)) -Color DarkGray
    }

    Write-Host ""
}

# The console's rendering style (Classic boxed layout or the
# new Compact Fluent-style prompts) - Config.json
# General.ConsoleStyle.
function Get-ConsoleStyle
{
    $Style = "Classic"

    if ($Global:Config -and $Global:Config.General -and $Global:Config.General.ConsoleStyle)
    {
        $Style = [string]$Global:Config.General.ConsoleStyle
    }

    return $Style
}

# Persists the style back to the app-dir Config.json (the same
# file Load-Config reads in console mode) so the choice sticks.
function Set-ConsoleStyle
{
    param([string]$Style)

    $Global:Config.General.ConsoleStyle = $Style

    try
    {
        $ConfigFile = Join-Path $PSScriptRoot "..\Config.json"
        $Global:Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -Encoding UTF8
    }
    catch {}
}

# Compact Fluent-style menu: no heavy box, numbered prompts with
# a bare ">" input line - reads like a modern CLI (winget, gh).
function Show-MenuCompact
{
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "PC Doctor Portable" -ForegroundColor Cyan -NoNewline
    Write-Host ("  v" + $Global:Config.General.Version) -ForegroundColor Yellow
    Write-Host "  " -NoNewline
    Write-Host (Get-UIText "MenuSubtitle") -ForegroundColor DarkGray
    Write-Host ""

    $Options = @(
        @{ Num = "1"; Text = "MenuOptAuto";  Color = "Green" },
        @{ Num = "2"; Text = "MenuOptInteractive"; Color = "Yellow" },
        @{ Num = "3"; Text = "MenuOptHistory";    Color = "Cyan" },
        @{ Num = "4"; Text = "MenuOptExit";       Color = "Red" },
        @{ Num = "5"; Text = "MenuOptStyle";      Color = "Magenta" }
    )

    foreach ($Opt in $Options)
    {
        # The localized strings embed their own "[N]" prefix (used
        # by the classic boxed layout) - strip it here so the
        # compact numbering does not duplicate it.
        $Label = [string](Get-UIText $Opt.Text) -replace '^\[[^\]]*\]\s*', ''

        Write-Host "  " -NoNewline
        Write-Host ($Opt.Num + " ") -ForegroundColor Cyan -NoNewline
        Write-Host $Label -ForegroundColor $Opt.Color
    }

    Write-Host ""
}

function Show-MenuClassic
{
    $MenuBox = {
        Write-Host ""
        Write-UIBoxTop
        Write-UIBoxLine -Line ("  " + (Get-UIText "MenuTitle")) -Color Yellow
        Write-UIBoxLine -Line ("  " + (Get-UIText "MenuSubtitle")) -Color Cyan
        Write-UIBoxLine -Line ""
        Write-UIBoxLine -Line ("  " + (Get-UIText "MenuOptAuto")) -Color Green
        Write-UIBoxLine -Line ("  " + (Get-UIText "MenuOptInteractive")) -Color Yellow
        Write-UIBoxLine -Line ("  " + (Get-UIText "MenuOptHistory")) -Color Cyan
        Write-UIBoxLine -Line ("  " + (Get-UIText "MenuOptExit")) -Color Red
        Write-UIBoxLine -Line ("  " + (Get-UIText "MenuOptStyle")) -Color Magenta
        Write-UIBoxBottom
        Write-Host ""
    }

    Clear-Host
    & $MenuBox
}

function Show-Menu
{
    if ((Get-ConsoleStyle) -eq "Compact")
    {
        Clear-Host
        Show-MenuCompact
    }
    else
    {
        Show-MenuClassic
    }

    $Prompt = if ((Get-ConsoleStyle) -eq "Compact") { (Get-UIText "CompactPrompt") } else { (Get-UIText "SelectOption") }

    do
    {
        $Choice = Read-Host $Prompt

        switch ($Choice)
        {
            "1"
            {
                $Global:AppMode = "AUTO"
                Write-Log ((Get-UIText "ModeSelected") -f "Auto") "SUCCESS"
                return
            }

            "2"
            {
                $Global:AppMode = "INTERACTIVE"
                Write-Log ((Get-UIText "ModeSelected") -f "Interactive") "SUCCESS"
                return
            }

            "3"
            {
                $Global:AppExit = $true
                return
            }

            "4"
            {
                Show-HistoryList
                Read-Host (Get-UIText "MenuHistoryBack") | Out-Null

                if ((Get-ConsoleStyle) -eq "Compact")
                {
                    Clear-Host
                    Show-MenuCompact
                }
                else
                {
                    Clear-Host
                    Show-MenuClassic
                }
            }

            "5"
            {
                $NewStyle = if ((Get-ConsoleStyle) -eq "Compact") { "Classic" } else { "Compact" }

                Set-ConsoleStyle -Style $NewStyle

                $StyleName = if ($NewStyle -eq "Compact") { (Get-UIText "StyleCompact") } else { (Get-UIText "StyleClassic") }

                Write-Host ""
                Write-Host ("  " + ((Get-UIText "StyleNow") -f $StyleName)) -ForegroundColor Cyan
                Write-Host ""

                Start-Sleep -Milliseconds 700

                Clear-Host

                if ($NewStyle -eq "Compact")
                {
                    Show-MenuCompact
                }
                else
                {
                    Show-MenuClassic
                }

                $Prompt = if ($NewStyle -eq "Compact") { (Get-UIText "CompactPrompt") } else { (Get-UIText "SelectOption") }
            }

            Default
            {
                Write-Host ""
                Write-Host ("  " + (Get-UIText "InvalidChoice")) -ForegroundColor Red
                Write-Host ""
            }
        }
    } while ($true)
}
