# ==========================================================
# PC Doctor Portable
# Logger Module v1.1
# Code Knot Technology
# ==========================================================
# Single buffered UTF-8 writer (industry standard) plus a
# console output with colored status chips.
# ==========================================================

$Global:LogFolder = Join-Path $PSScriptRoot "..\Logs"

if (-not (Test-Path $Global:LogFolder))
{
    New-Item -ItemType Directory -Path $Global:LogFolder -Force | Out-Null
}

$Global:LogFile = Join-Path $Global:LogFolder (
    "Log_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".txt"
)

$Global:LogWriter = New-Object System.IO.StreamWriter(
    $Global:LogFile,
    $true,
    (New-Object System.Text.UTF8Encoding($true))
)
$Global:LogWriter.AutoFlush = $true

# Writes to the log file only (used by UI frames so the
# console stays clean while the file keeps full detail)
function Write-LogFile
{
    param(

        [AllowEmptyString()]
        [string]$Message = "",

        [ValidateSet("INFO","SUCCESS","WARNING","ERROR")]
        [string]$Level = "INFO"

    )

    if ($Message -eq "")
    {
        if ($Global:LogWriter) { $Global:LogWriter.WriteLine("") }
        return
    }

    $Time = Get-Date -Format "HH:mm:ss"
    $Line = "[$Time] [$Level] $Message"

    if ($Global:LogWriter)
    {
        $Global:LogWriter.WriteLine($Line)
    }
    else
    {
        Add-Content -Path $Global:LogFile -Value $Line -Encoding UTF8
    }
}

function Write-Log
{
    param(

        [AllowEmptyString()]
        [string]$Message = "",

        [ValidateSet("INFO","SUCCESS","WARNING","ERROR")]
        [string]$Level = "INFO"

    )

    # Blank line
    if ($Message -eq "")
    {
        Write-Host ""
        Write-LogFile -Message ""
        return
    }

    $Chip = switch ($Level)
    {
        "INFO"    { "[INFO]" }
        "SUCCESS" { "[ OK ]" }
        "WARNING" { "[WARN]" }
        "ERROR"   { "[ERR ]" }
    }

    $Color = switch ($Level)
    {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }

    Write-Host ("  " + $Chip + "  " + $Message) -ForegroundColor $Color
    Write-LogFile -Message $Message -Level $Level
}

function Close-Logger
{
    if ($Global:LogWriter)
    {
        try { $Global:LogWriter.Dispose() } catch {}
        $Global:LogWriter = $null
    }
}
