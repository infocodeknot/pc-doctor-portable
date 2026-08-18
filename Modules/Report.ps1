# ==========================================================
# PC Doctor Portable
# Report Module v1.1
# Code Knot Technology
# ==========================================================
# Professional report: module results with durations,
# verification status and full system information.
# ==========================================================

$Global:LastModuleStatus = "FAILED"

Write-Step (Get-UIText "StepReport")

$ReportFolder = Join-Path $PSScriptRoot "..\Reports"

if (-not (Test-Path $ReportFolder))
{
    New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null
}

$ReportFile = Join-Path $ReportFolder ("Report_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".txt")

# ----------------------------------------------------------
# System information
# ----------------------------------------------------------

$OSName     = "Unknown"
$OSVersion  = "Unknown"
$CPU        = "Unknown"
$TotalRAM   = "Unknown"
$Uptime     = "Unknown"

try
{
    $OSInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $CPUInfo = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($OSInfo)
    {
        $OSName    = $OSInfo.Caption
        $OSVersion = $OSInfo.Version
        $TotalRAM  = ("{0} GB" -f [math]::Round($OSInfo.TotalVisibleMemorySize / 1MB, 1))
        $Uptime    = ((Get-Date) - $OSInfo.LastBootUpTime).ToString("d\.hh\:mm")
    }

    if ($CPUInfo)
    {
        $CPU = $CPUInfo.Name
    }
}
catch {}

# ----------------------------------------------------------
# Build report
# ----------------------------------------------------------

$Report = @()

$Report += "=========================================================="
$Report += "               PC Doctor Portable Report"
$Report += "=========================================================="
$Report += ""
$Report += "Date              : $(Get-Date)"
$Report += "Computer          : $env:COMPUTERNAME"
$Report += "User              : $env:USERNAME"
$Report += ""

$Report += "================ MODULE STATUS =================="

foreach ($Item in $Global:ModuleResults)
{
    $Report += ("{0,-25} : {1,-10} ({2})" -f $Item.Module, $Item.Status, $Item.Duration)
}

$Report += ""

$Report += "================ VERIFICATION ==================="

$Report += ("Internet          : {0}" -f $Global:Verification.Internet)
$Report += ("Windows Update    : {0}" -f $Global:Verification.WindowsUpdate)
$Report += ("Drivers           : {0}" -f $Global:Verification.Drivers)
$Report += ("Software Update   : {0}" -f $Global:Verification.Software)
$Report += ("Microsoft Store   : {0}" -f $Global:Verification.Store)
$Report += ("Windows Repair    : {0}" -f $Global:Verification.Repair)
$Report += ("Cleanup           : {0}" -f $Global:Verification.Cleanup)
$Report += ("Optimization      : {0}" -f $Global:Verification.Optimization)
$Report += ("Restart           : {0}" -f $Global:Verification.Restart)
$Report += ("Administrator     : {0}" -f $Global:Verification.Administrator)
$Report += ("Disk Space        : {0}" -f $Global:Verification.DiskSpace)
$Report += ("Overall Status    : {0}" -f $Global:Verification.OverallStatus)

$Report += ""

$Report += "================ SYSTEM INFORMATION ============="
$Report += ("Operating System  : {0}" -f $OSName)
$Report += ("OS Version        : {0}" -f $OSVersion)
$Report += ("Processor         : {0}" -f $CPU)
$Report += ("Total RAM         : {0}" -f $TotalRAM)
$Report += ("Uptime            : {0}" -f $Uptime)

$Report += ""
$Report += "=========================================================="
$Report += "              Code Knot Technology"
$Report += "=========================================================="

try
{
    $Report | Out-File -FilePath $ReportFile -Encoding UTF8

    # Also generate HTML report
    $HtmlFile = $ReportFile -replace '\.txt$', '.html'
    $OverallColor = if ($Global:Verification.OverallStatus -eq 'HEALTHY') { '#15803D' } elseif ($Global:Verification.OverallStatus -eq 'WARNING') { '#92400E' } else { '#B91C1C' }

    $Html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>PC Doctor Portable Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm')</title>
<style>
  body { font-family: 'Segoe UI', system-ui, sans-serif; background: #0f172a; color: #e2e8f0; margin: 0; padding: 20px; }
  .container { max-width: 800px; margin: 0 auto; }
  .header { background: linear-gradient(135deg, #1e3a5f, #0d2838); padding: 20px; border-radius: 12px; margin-bottom: 20px; }
  .header h1 { margin: 0; color: #4fc1ff; font-size: 1.5rem; }
  .header p { margin: 4px 0 0; color: #8b98a9; font-size: 0.9rem; }
  .card { background: #1e293b; border: 1px solid #2d3644; border-radius: 10px; padding: 16px; margin: 12px 0; }
  .card h2 { margin: 0 0 10px; color: #94a3b8; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 1px; }
  table { width: 100%; border-collapse: collapse; }
  th, td { padding: 8px 12px; text-align: left; border-bottom: 1px solid #2d3644; font-size: 0.9rem; }
  th { color: #64748b; font-weight: 600; }
  .status-OK { color: #34d399; font-weight: 600; }
  .status-WARN { color: #fbbf24; font-weight: 600; }
  .status-FAIL { color: #f87171; font-weight: 600; }
  .overall { font-size: 1.2rem; font-weight: bold; padding: 12px; border-radius: 8px; text-align: center; margin: 10px 0; }
  .footer { text-align: center; color: #475569; font-size: 0.8rem; margin-top: 20px; padding: 10px; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>PC Doctor Portable Report</h1>
    <p>$(Get-Date -Format 'dddd, MMMM dd, yyyy - HH:mm') | $env:COMPUTERNAME | $env:USERNAME</p>
  </div>

  <div class="overall" style="background: ${OverallColor}22; color: ${OverallColor}; border: 1px solid ${OverallColor}">
    Overall Status: $($Global:Verification.OverallStatus)
  </div>

  <div class="card">
    <h2>Module Results</h2>
    <table>
      <tr><th>Module</th><th>Status</th><th>Duration</th></n"@ 

    foreach ($Item in $Global:ModuleResults) {
        $CssClass = switch ($Item.Status) { 'SUCCESS' { 'status-OK' } 'WARNING' { 'status-WARN' } 'FAILED' { 'status-FAIL' } Default { '' }
        }
        $Html += "      <tr><td>$($Item.Module)</td><td class=\"$CssClass\">$($Item.Status)</td><td>$($Item.Duration)</td></tr>`n"
    }

    $Html += @"
    </table>
  </div>

  <div class="card">
    <h2>System Information</h2>
    <table>
      <tr><th>Property</th><th>Value</th></tr>
      <tr><td>Operating System</td><td>$OSName</td></tr>
      <tr><td>OS Version</td><td>$OSVersion</td></tr>
      <tr><td>Processor</td><td>$CPU</td></tr>
      <tr><td>Total RAM</td><td>$TotalRAM</td></tr>
      <tr><td>Uptime</td><td>$Uptime</td></tr>
    </table>
  </div>

  <div class="footer">
    PC Doctor Portable v1.2 - Code Knot Technology - Windows Maintenance & Repair Tool
  </div>
</div>
</body>
</html>
"@

    $Html | Out-File -FilePath $HtmlFile -Encoding UTF8
    Write-Log ((Get-UIText "ReportSaved") -f $ReportFile) "SUCCESS"
    $Global:LastModuleStatus = "SUCCESS"
}
catch
{
    Write-Log "Report could not be saved : $($_.Exception.Message)" "ERROR"
    $Global:LastModuleStatus = "FAILED"
}
