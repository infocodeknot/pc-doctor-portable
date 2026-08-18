# ==========================================================
# PC Doctor Portable - App Icon Generator
# Code Knot Technology
# ==========================================================
# Draws a professional 256x256 icon (dark rounded tile with
# a cyan repair cross) and saves it to Assets\PCDoctor.ico.
# Used by the Inno Setup installer for shortcuts.
# ==========================================================

Add-Type -AssemblyName System.Drawing

$Root  = Split-Path -Parent $PSScriptRoot
$OutPath = Join-Path $Root "Assets\PCDoctor.ico"

$Size = 256
$Bmp = New-Object System.Drawing.Bitmap($Size, $Size)
$G = [System.Drawing.Graphics]::FromImage($Bmp)
$G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$G.Clear([System.Drawing.Color]::FromArgb(255, 13, 17, 23))

function New-RoundRectPath
{
    param([int]$X, [int]$Y, [int]$W, [int]$H, [int]$R)

    $Path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $D = $R * 2

    $Path.AddArc($X, $Y, $D, $D, 180, 90)
    $Path.AddArc($X + $W - $D, $Y, $D, $D, 270, 90)
    $Path.AddArc($X + $W - $D, $Y + $H - $D, $D, $D, 0, 90)
    $Path.AddArc($X, $Y + $H - $D, $D, $D, 90, 90)
    $Path.CloseFigure()

    return $Path
}

# Tile background (rounded rect with subtle gradient)
$TileRect = New-Object System.Drawing.Rectangle(8, 8, 240, 240)
$Gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $TileRect,
    [System.Drawing.Color]::FromArgb(255, 24, 34, 46),
    [System.Drawing.Color]::FromArgb(255, 37, 52, 70),
    45.0
)
$TilePath = New-RoundRectPath -X 8 -Y 8 -W 240 -H 240 -R 52
$G.FillPath($Gradient, $TilePath)

# Tile border
$BorderPen = New-Object System.Drawing.Pen(
    [System.Drawing.Color]::FromArgb(120, 79, 193, 255),
    3
)
$G.DrawPath($BorderPen, $TilePath)

# Repair cross (cyan, rounded caps)
$CrossPen = New-Object System.Drawing.Pen(
    [System.Drawing.Color]::FromArgb(255, 79, 193, 255),
    44
)
$CrossPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$CrossPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

$G.DrawLine($CrossPen, 128, 62, 128, 194)
$G.DrawLine($CrossPen, 62, 128, 194, 128)

# Center "check" accent (green) - a small dot in the middle
$CheckBrush = New-Object System.Drawing.SolidBrush(
    [System.Drawing.Color]::FromArgb(255, 61, 220, 132)
)
$G.FillEllipse($CheckBrush, 106, 106, 44, 44)

# Cross inner fill (dark) to make the green center pop
$InnerPen = New-Object System.Drawing.Pen(
    [System.Drawing.Color]::FromArgb(255, 13, 17, 23),
    8
)
$InnerPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$InnerPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$G.DrawLine($InnerPen, 128, 104, 128, 152)
$G.DrawLine($InnerPen, 104, 128, 152, 128)

# Save as .ico (Icon.Save takes a Stream)
$IconHandle = $Bmp.GetHicon()
$Icon = [System.Drawing.Icon]::FromHandle($IconHandle)

$FileStream = [System.IO.File]::Create($OutPath)
try
{
    $Icon.Save($FileStream)
}
finally
{
    $FileStream.Dispose()
}

$G.Dispose()
$Bmp.Dispose()
$Icon.Dispose()

Write-Host ("Icon saved : " + $OutPath)
