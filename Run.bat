@echo off
title PC Doctor Portable v1.2

cd /d "%~dp0"

:: Check Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ==============================================
    echo        Administrator Permission Required
    echo ==============================================
    echo.
    echo Restarting as Administrator...
    echo.

    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo Starting PC Doctor Portable...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Main.ps1"
set EXITCODE=%errorLevel%

if not "%EXITCODE%"=="0" (
    echo.
    echo An error occurred during execution (exit code %EXITCODE%).
    echo.
    pause
)

echo.
echo ==============================================
echo            PC Doctor Portable Finished
echo ==============================================
echo.

pause
