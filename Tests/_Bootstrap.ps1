# ==========================================================
# PC Doctor Portable - Pester test bootstrap
# Loads the core modules exactly like Main.ps1 does, then
# loads Config.json and the localized strings. Safe: nothing
# destructive is executed here (same as .freebuff/smoke-test).
#
# Pester 3.4 runs every test file in its own session, so this
# is dot-sourced once per test file. Logger.ps1 opens the log
# file at load time, so we close it right away to release the
# handle - otherwise two files loading within the same second
# collide on the same filename (file lock).
# ==========================================================

$ErrorActionPreference = "Stop"

$Global:TestRoot    = Split-Path -Parent $PSScriptRoot
$Global:TestModules = Join-Path $Global:TestRoot "Modules"

# Exact same load order as Main.ps1
. (Join-Path $Global:TestModules "Logger.ps1")
. (Join-Path $Global:TestModules "UI.ps1")
. (Join-Path $Global:TestModules "Common.ps1")
. (Join-Path $Global:TestModules "Update.ps1")
. (Join-Path $Global:TestModules "TaskScheduler.ps1")
. (Join-Path $Global:TestModules "Banner.ps1")
. (Join-Path $Global:TestModules "Startup.ps1")
. (Join-Path $Global:TestModules "Menu.ps1")

# Load config + strings (throws if Config.json is broken)
Load-Config

# Release the log handle now; Write-Log still prints to the
# console during tests. Re-loading in another test file opens
# the same (append) file without a lock conflict.
Close-Logger

# Tests must not abort on non-terminating errors
$ErrorActionPreference = "Continue"

# All module entry scripts must set this on every path
$Global:LastModuleStatus = "SUCCESS"
