@echo off
title PC Doctor Portable v1.2
echo.
echo   Starting PC Doctor Portable...
echo   (Close this window after the GUI opens)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0App\PCDoctor-GUI.ps1"
pause
