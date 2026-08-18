# ==========================================================
# PC Doctor Portable - Elevated Task Scheduler helper
# Code Knot Technology
# ==========================================================
# The GUI launches this script elevated (Start-Process
# -Verb RunAs) because registering a task with /RL HIGHEST
# needs administrator rights. The result is written to a
# temp file the GUI polls.
#
#   powershell -File App\Register-TaskElevated.ps1 -Action Register -Day 1 -Time 09:00
# ==========================================================

param(
    [ValidateSet("Register", "Unregister")]
    [string]$Action = "Register",
    [int]$Day = 0,
    [string]$Time = "09:00"
)

$AppRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $AppRoot "Modules\Logger.ps1")
. (Join-Path $AppRoot "Modules\Common.ps1")
. (Join-Path $AppRoot "Modules\TaskScheduler.ps1")

$ResultFile = Join-Path $env:TEMP "PCDoctorTaskResult.txt"

try
{
    if ($Action -eq "Register")
    {
        $OK = Register-PCScheduledTask -Day $Day -Time $Time
    }
    else
    {
        $OK = Unregister-PCScheduledTask
    }

    Set-Content -Path $ResultFile -Value ("OK=" + $OK) -Encoding UTF8
}
catch
{
    Set-Content -Path $ResultFile -Value ("OK=False ERR=" + $_.Exception.Message) -Encoding UTF8
}
