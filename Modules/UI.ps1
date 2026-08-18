# ==========================================================
# PC Doctor Portable
# UI Module v1.1
# Code Knot Technology
# ==========================================================
# World-class console rendering:
#   - boxed module frames (double-line borders)
#   - colored status chips [ OK ] [FAIL] [WARN] [SKIP]
#   - progress bars and a spinner for waiting
# All glyphs are built from [char] codes so the source stays
# pure ASCII (safe for Windows PowerShell 5.1 parsing) while
# the console renders real box-drawing characters.
# ==========================================================

# Enable UTF-8 output so box/block glyphs render everywhere
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Global:UIConsole = @{
    TL = [char]0x2554   # top-left corner
    TB = [char]0x2550   # top/bottom border
    TR = [char]0x2557   # top-right corner
    VB = [char]0x2551   # vertical border
    BL = [char]0x255A   # bottom-left corner
    BR = [char]0x255D   # bottom-right corner
    FB = [char]0x2588   # filled block (progress)
    EB = [char]0x2591   # empty block (progress)
}

function Get-UIChar
{
    param([string]$Name)

    if ($Global:UIConsole -and $Global:UIConsole.ContainsKey($Name))
    {
        return $Global:UIConsole[$Name]
    }

    switch ($Name)
    {
        "TL" { return "+" }
        "TB" { return "=" }
        "TR" { return "+" }
        "VB" { return "|" }
        "BL" { return "+" }
        "BR" { return "+" }
        "FB" { return "#" }
        "EB" { return "." }
        Default { return "?" }
    }
}

function Get-UIWidth
{
    try
    {
        $W = $Host.UI.RawUI.WindowSize.Width
        if ($W -gt 0) { return [Math]::Min(100, [Math]::Max(60, $W)) }
    }
    catch {}

    return 78
}

function Get-UIInnerWidth
{
    return (Get-UIWidth) - 4
}

# ----------------------------------------------------------
# Box primitives
# ----------------------------------------------------------

function Write-UIBoxTop
{
    $Inner = Get-UIInnerWidth
    $Border = ([string](Get-UIChar "TB")) * ($Inner + 2)
    Write-Host (([string](Get-UIChar "TL")) + $Border + ([string](Get-UIChar "TR"))) -ForegroundColor DarkCyan
}

function Write-UIBoxBottom
{
    $Inner = Get-UIInnerWidth
    $Border = ([string](Get-UIChar "TB")) * ($Inner + 2)
    Write-Host (([string](Get-UIChar "BL")) + $Border + ([string](Get-UIChar "BR"))) -ForegroundColor DarkCyan
}

function Write-UIBoxLine
{
    param(
        [string]$Line = "",
        [string]$Color = "White"
    )

    $Inner = Get-UIInnerWidth

    if ($Line.Length -gt $Inner) { $Line = $Line.Substring(0, $Inner) }

    Write-Host ((Get-UIChar "VB") + " ") -ForegroundColor DarkCyan -NoNewline
    Write-Host $Line.PadRight($Inner) -ForegroundColor $Color -NoNewline
    Write-Host (" " + (Get-UIChar "VB")) -ForegroundColor DarkCyan
}

function Write-UIBox
{
    param(
        [string[]]$Lines,
        [string]$Color = "White"
    )

    Write-UIBoxTop
    foreach ($Line in $Lines) { Write-UIBoxLine -Line $Line -Color $Color }
    Write-UIBoxBottom
}

# ----------------------------------------------------------
# Status chips
# ----------------------------------------------------------

function Get-UIStatusChip
{
    param([string]$Status)

    switch ($Status.ToUpper())
    {
        "SUCCESS" { return "[ OK ]" }
        "FAILED"  { return "[FAIL]" }
        "WARNING" { return "[WARN]" }
        "SKIPPED" { return "[SKIP]" }
        "MISSING" { return "[MISS]" }
        "REQUIRED"{ return "[  !  ]" }
        Default   { return ("[" + $Status.ToUpper().PadRight(4) + "]") }
    }
}

function Get-UIStatusColor
{
    param([string]$Status)

    switch ($Status.ToUpper())
    {
        "SUCCESS" { return "Green" }
        "FAILED"  { return "Red" }
        "WARNING" { return "Yellow" }
        "SKIPPED" { return "DarkGray" }
        "MISSING" { return "Red" }
        "REQUIRED"{ return "Yellow" }
        Default   { return "Cyan" }
    }
}

function Write-UIStatusLine
{
    param(
        [string]$Status,
        [string]$Message
    )

    $Chip  = Get-UIStatusChip -Status $Status
    $Color = Get-UIStatusColor -Status $Status

    Write-Host ("  " + $Chip + "  " + $Message) -ForegroundColor $Color
}

# ----------------------------------------------------------
# Module frames
# ----------------------------------------------------------

function Write-UIModuleStart
{
    param(
        [string]$Name,
        [int]$Index = 0,
        [int]$Total = 0
    )

    $Sequence = if ($Total -gt 0) { ("[{0}/{1}]" -f $Index, $Total) } else { ("[{0}]" -f $Index) }

    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + $Sequence + "  " + $Name.ToUpper()) -Color Yellow
    Write-UIBoxBottom
}

function Write-UIModuleEnd
{
    param(
        [string]$Name,
        [string]$Status,
        [string]$Duration
    )

    $Chip  = Get-UIStatusChip -Status $Status
    $Color = Get-UIStatusColor -Status $Status

    Write-Host ""
    Write-UIBoxTop
    Write-UIBoxLine -Line ("  " + $Chip + "  " + $Name + "  (" + $Duration + ")") -Color $Color
    Write-UIBoxBottom
    Write-Host ""
}

# ----------------------------------------------------------
# Progress bar
# ----------------------------------------------------------

function Write-UIProgressBar
{
    param(
        [double]$Percent,
        [string]$Label = "",
        [switch]$Complete
    )

    $Width = 28
    $P = [Math]::Max(0, [Math]::Min(100, $Percent))
    $Filled = [int]($Width * $P / 100)

    $Bar = (([string](Get-UIChar "FB")) * $Filled) + (([string](Get-UIChar "EB")) * ($Width - $Filled))

    $Text = ("  " + $Bar + (" {0,3}%" -f [int]$P) + "  " + $Label)

    if ($Complete)
    {
        Write-Host ("`r" + $Text + "  ") -ForegroundColor Green
    }
    else
    {
        Write-Host ("`r" + $Text + "  ") -NoNewline -ForegroundColor Cyan
    }
}

# ----------------------------------------------------------
# Spinner (for short waits)
# ----------------------------------------------------------

function Show-UISpinner
{
    param(
        [int]$Seconds,
        [string]$Label
    )

    $Frames = @("|", "/", "-", "\")

    for ($i = 0; $i -lt $Seconds; $i++)
    {
        $Frame = $Frames[$i % 4]
        Write-Host ("`r  " + $Frame + "  " + $Label + "   ") -ForegroundColor Cyan -NoNewline
        Start-Sleep 1
    }

    Write-Host ("`r    " + $Label + " ... done." + (" " * 10))
}

# ----------------------------------------------------------
# Branding: replace the host console window's icon (the
# PowerShell logo) with the toolkit's own icon, so nothing
# on screen suggests the app runs on PowerShell.
# Uses the WM_SETICON trick on the console window.
# ----------------------------------------------------------

function Set-ConsoleIcon
{
    param([string]$IconPath = "")

    if (-not $IconPath -or -not (Test-Path $IconPath))
    {
        return
    }

    try
    {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ConsoleIconNative
{
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr GetConsoleWindow();
}
"@ -ErrorAction Stop
    }
    catch
    {
        return
    }

    try
    {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $Handle  = [ConsoleIconNative]::GetConsoleWindow()

        if ($Handle -eq [IntPtr]::Zero)
        {
            return
        }

        # 0x80 = WM_SETICON, wParam 1 = big icon, 0 = small icon
        $Icon = New-Object System.Drawing.Icon($IconPath)

        $null = [ConsoleIconNative]::SendMessage($Handle, 0x80, [IntPtr]1, $Icon.Handle)
        $null = [ConsoleIconNative]::SendMessage($Handle, 0x80, [IntPtr]0, $Icon.Handle)

        $Icon.Dispose()
    }
    catch {}
}
