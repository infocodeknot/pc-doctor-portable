============================================================
                  PC Doctor Portable
                 Version 1.2 (Release)
              Code Knot Technology
============================================================

DESCRIPTION
-----------
PC Doctor Portable is a portable Windows Maintenance & Repair
Tool developed using PowerShell. No installation is required.

It automates common maintenance tasks:

  Internet connectivity verification (ICMP + DNS + HTTPS)
  Automatic network repair (DNS flush, Winsock, TCP/IP reset)
  Auto-update check against GitHub releases
  Full bilingual UI - GUI + console (English / Hindi)
  Dark/light theme, settings panel, run summary screen
  Module detail view and weekly auto-run scheduler
  One-click download of new versions from the GUI
  Windows Update via the official Windows Update Agent
  Driver updates via the Windows Update pipeline
  Software updates via Winget
  Microsoft Store app updates via Winget (msstore source)
  Windows repair (DISM & SFC) with real exit-code handling
  Temporary file cleanup with freed-space reporting
  Browser cache cleanup (Chrome, Edge, Firefox)
  Browser cookies cleanup (Chrome, Edge, Firefox)
  Prefetch and crash dump cleanup
  Disk Cleanup (cleanmgr)
  Windows Update cache cleanup (optional, off by default)
  Windows optimization (SSD ReTrim, Explorer restart,
  thumbnail/icon cache cleanup)
  System verification based on actual module results
  Automatic report generation with system information
  Restart management with auto-restart option

------------------------------------------------------------
SYSTEM REQUIREMENTS
------------------------------------------------------------

Operating System
    Windows 10
    Windows 11

PowerShell
    Windows PowerShell 5.1 or later

Permissions
    Administrator privileges are recommended (required for
    DISM, SFC, restore points and driver/update installs).

Internet
    Required for Windows Update, Driver Update, Winget and
    Microsoft Store updates. If unavailable, online modules
    are skipped automatically.

------------------------------------------------------------
HOW TO RUN
------------------------------------------------------------

1. Open the PCDoctorPortable folder.
2. Double-click Run.bat
3. Approve the UAC prompt if shown.
4. Select the desired mode.
5. Wait until the tool completes.

Modes:
    [1] Auto Mode        - runs everything unattended
    [2] Interactive Mode - asks before each major step
    [3] Exit

------------------------------------------------------------
CONFIGURATION (Config.json)
------------------------------------------------------------

Every feature can be enabled or disabled in Config.json:

  Cleanup
    CleanTemp             - temporary folders
    RunDiskCleanup        - cleanmgr /autoclean
    CleanCookies          - browser cookies (browsers must be closed)
    CleanBrowserCache     - browser cache (browsers must be closed)
    CleanPrefetch         - Windows prefetch files
    CleanCrashDumps       - Minidump + MEMORY.DMP
    CleanWindowsUpdateCache - SoftwareDistribution cache (off by default)

  Optimization
    OptimizeDrives        - ReTrim SSDs only
    RestartExplorer       - restart Windows Explorer
    ClearThumbnailCache   - thumbnail + icon cache

  WindowsUpdate / Drivers / Winget / Store
    Enabled               - turn each update source on/off

  Repair
    RunDISM               - DISM /RestoreHealth
    RunSFC                - sfc /scannow

  Restart
    AutoRestart           - restart automatically when needed (Auto Mode)

  Retention
    KeepLogs / KeepReports / KeepBackups - old artifacts are
    pruned automatically on every run.

------------------------------------------------------------
DOCUMENTATION
------------------------------------------------------------

  README.txt          - this file (English)
  Assets\README_HINDI.txt - Hindi documentation
  LICENSE.txt         - MIT License

------------------------------------------------------------
PROJECT STRUCTURE
------------------------------------------------------------

Main.ps1
Run.bat
Config.json

Modules\
Assets\
Logs\
Reports\
Backups\
Temp\

------------------------------------------------------------
REPORTS
------------------------------------------------------------

Generated reports are stored in:

  Reports\

Reports contain module status with durations, verification
results and system information (OS, processor, RAM, uptime).

------------------------------------------------------------
LOGS
------------------------------------------------------------

Execution logs are stored in:

  Logs\

------------------------------------------------------------
AUTO-UPDATE
------------------------------------------------------------

On every run the tool checks GitHub releases for a newer
version (Config.json > General > UpdateUrl). The release tag
must contain a version number (example: v1.2.0). The GUI
shows the result in the header; the console logs it.

To publish an update:
  1. Create a GitHub repository and set UpdateUrl to its
     releases/latest API URL.
  2. Push a tag like v1.2.0 when you release.

------------------------------------------------------------
LANGUAGES
------------------------------------------------------------

The GUI ships with an English / Hindi language switcher in
the top-right corner. Translations live in App\strings.json
(add more strings or languages there).

------------------------------------------------------------
CODE SIGNING
------------------------------------------------------------

Windows shows a SmartScreen warning for unsigned installers
("Windows protected your PC - Unknown publisher"). To make
the installer trusted you need a code-signing certificate
and must sign the Setup.exe before distributing it.

What is needed:

  1. A code-signing certificate from a public CA. Options:
     - EV certificate (DigiCert, Sectigo, SSL.com, ~$300-500/yr)
       - requires a hardware token/USB key, company validation
       - instant SmartScreen trust - no warning at all
     - OV / IV certificate (same CAs, ~$100-300/yr)
       - cheaper, no hardware token
       - builds reputation over time; SmartScreen may still
         warn for a while ("Unknown publisher" until enough
         users install it)
     - Self-signed certificate
       - free, for internal testing only - still warns

  2. Sign the installer with your .pfx:

     pwsh -File Tools\Sign-Installer.ps1 `
         -PfxPath C:\certs\mycert.pfx -PfxPassword "secret"

     or build and sign in one step:

     pwsh -File Tools\Build-Installer.ps1 `
         -SignPfxPath C:\certs\mycert.pfx -SignPfxPassword "secret"

  Signing uses SHA-256 with a public RFC3161 timestamp
  server, so the signature stays valid after the cert
  expires. After signing, the file shows "Valid signature"
  and the publisher name in Properties > Digital Signatures.

  Alternative (Windows SDK):

     signtool sign /fd SHA256 /tr http://timestamp.digicert.com `
         /td SHA256 /f mycert.pfx /p secret PCDoctorPortable-Setup-1.1.exe

------------------------------------------------------------
KNOWN LIMITATIONS
------------------------------------------------------------

  Windows Update behavior depends on Microsoft services.
  Some repairs require a system restart.
  System Restore may be disabled on some systems.
  Some operations require an active internet connection.
  Browser cache/cookies are only cleaned while the browser
  is closed.

------------------------------------------------------------
VERSION
------------------------------------------------------------

Version : 1.2
Release : RC-1

------------------------------------------------------------
DEVELOPER
------------------------------------------------------------

Code Knot Technology

============================================================
End of Document
============================================================
