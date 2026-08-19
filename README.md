<div align="center">

[![Build Status](https://github.com/infocodeknot/pc-doctor-portable/actions/workflows/build.yml/badge.svg)](https://github.com/infocodeknot/pc-doctor-portable/actions)

# 🛠️ PC Doctor Portable

### Windows Maintenance & Repair Tool

**Version 1.2** · **Code Knot Technology** · **Pure PowerShell**

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-5391FE.svg)
![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4.svg)
![Version](https://img.shields.io/badge/Version-1.2.0-green.svg)
![Tests](https://img.shields.io/badge/Tests-47%2F47-passing-brightgreen.svg)

<br>

**PC Doctor Portable** is a comprehensive, portable Windows maintenance toolkit built entirely in PowerShell. It automates system cleanup, repair, updates, optimization, and verification — all with a professional GUI and bilingual support (English/Hindi).

[Download Latest Release](https://github.com/infocodeknot/pc-doctor-portable/releases/latest) · [Report Bug](https://github.com/infocodeknot/pc-doctor-portable/issues) · [Request Feature](https://github.com/infocodeknot/pc-doctor-portable/issues)

<br>

</div>

---

## ✨ Features

### 🔧 19 Maintenance Modules
| Module | What It Does |
|--------|-------------|
| 🌐 Internet Check | Verifies connectivity (ICMP + DNS + HTTPS) |
| 🔄 Network Repair | DNS flush, Winsock reset, TCP/IP reset |
| 🪟 Windows Update | Checks & installs updates via COM API |
| 🖥️ Driver Updates | Updates drivers via Windows Update pipeline |
| 📦 Software Updates | Updates installed apps via Winget |
| 🏪 Microsoft Store | Updates Store apps via Winget (msstore) |
| 🔧 Windows Repair | DISM image repair + SFC system file check |
| 🧹 Temp Cleanup | Cleans temp files, prefetch, crash dumps |
| 🍪 Browser Cleanup | Clears cache & cookies (Chrome, Edge, Firefox) |
| 💾 Disk Cleanup | Runs Windows Disk Cleanup (cleanmgr) |
| ⚡ Optimization | SSD ReTrim, Explorer restart, thumbnail cache |
| 💾 Restore Point | Creates system restore point |
| 📊 System Verification | Checks system health based on results |
| 📋 Auto Report | Generates detailed system report |
| 🔄 Restart Manager | Handles restart with auto-restart option |
| 📅 Task Scheduler | Weekly auto-run via Windows Task Scheduler |
| 🔔 Toast Notifications | Background run completion alerts |
| 📜 Run History | Browse past logs and reports |
| 💬 Feedback Dialog | Report bugs with system diagnostics |

### 🖥️ Professional GUI
- **Fluent-Style Navigation** — Dashboard, Modules, Settings, History
- **Live Dashboard** — Real-time RAM/Disk/CPU gauges, pending updates count
- **Dark/Light/System Themes** — Automatic OS theme detection
- **Bilingual Support** — English + Hindi (हिंदी) with one-click switch
- **Smooth Animations** — 220ms fade transitions between views
- **System Tray** — Minimize to background, right-click menu

### 💻 Console Version
- **Classic Mode** — ASCII art banner, colored progress bars
- **Compact Mode** — Fluent-style numbered prompts (like modern CLI)
- **Interactive Mode** — Step-by-step with confirmations
- **Auto Mode** — Run everything unattended

### 📦 Installer
- **Inno Setup** — Professional Windows installer (2.1 MB)
- **Silent Install** — `PCDoctorPortable-Setup-1.2.exe /SILENT`
- **Start Menu + Desktop** shortcuts
- **Code Signing Ready** — Sign with your PFX certificate

---

## 📸 Screenshots

> *Screenshots will be added after the first release. The GUI features a dark theme with a gradient header, live system gauges, and a Fluent-style navigation rail.*

---

## 🚀 Quick Start

### Option 1: Portable (No Install)
```powershell
# Run GUI
powershell -ExecutionPolicy Bypass -File "App\PCDoctor-GUI.ps1"

# Run Console
.\Run.bat
```

### Option 2: Install
1. Download `PCDoctorPortable-Setup-1.2.exe`
2. Run the installer
3. Launch from Start Menu or Desktop

### Option 3: Silent Install
```powershell
PCDoctorPortable-Setup-1.2.exe /SILENT
```

---

## 🧪 Testing

```powershell
# Run all 47 Pester tests
pwsh -File Tools\Run-Tests.ps1

# Run GUI self-test (no window)
powershell -File App\PCDoctor-GUI.ps1 -SelfTest

# Build installer (requires Inno Setup)
pwsh -File Tools\Build-Installer.ps1
```

---

## 📁 Project Structure

```
PCDoctorPortable/
├── Main.ps1                    # Entry point
├── Config.json                 # All settings & toggles
├── Run.bat                     # Console launcher
├── README.md                   # This file
├── LICENSE.txt                 # MIT License
├── App/
│   ├── PCDoctor-GUI.ps1        # WPF GUI (3,000+ lines)
│   ├── strings.json            # EN + HI translations
│   └── Register-TaskElevated.ps1
├── Modules/
│   ├── Banner.ps1              # Console banners
│   ├── Menu.ps1                # Interactive menu
│   ├── UI.ps1                  # Colors, progress bars
│   ├── Common.ps1              # Shared helpers
│   ├── Cleanup.ps1             # Temp/cache/cookie cleanup
│   ├── Repair.ps1              # DISM + SFC
│   ├── Optimize.ps1            # SSD, Explorer, thumbnails
│   ├── WindowsUpdate.ps1       # Windows Update
│   ├── Drivers.ps1             # Driver updates
│   ├── Winget.ps1              # Software updates
│   ├── Store.ps1               # Microsoft Store
│   ├── TaskScheduler.ps1       # Task Scheduler + toast
│   └── ... (19 modules total)
├── Tests/
│   ├── Config.Tests.ps1        # Config validation
│   ├── Core.Tests.ps1          # Function tests
│   ├── Cleanup.Tests.ps1       # Cleanup tests
│   ├── Modules.Tests.ps1       # Module contract tests
│   └── Update.Tests.ps1        # Version parser tests
├── Tools/
│   ├── Build-Installer.ps1     # Inno Setup builder
│   ├── Run-Tests.ps1           # CI test runner
│   ├── New-SignedCert.ps1      # Generate test cert
│   └── Sign-Installer.ps1      # Sign installer
├── Assets/
│   └── PCDoctor.ico            # App icon
├── Installer/
│   └── PCDoctorPortable.iss    # Inno Setup script
├── .github/workflows/
│   └── build.yml               # CI/CD pipeline
├── Logs/                       # Timestamped logs
└── Reports/                    # Auto-generated reports
```

---

## ⚙️ Configuration

Edit `Config.json` to customize behavior:

```json
{
  "General": {
    "ToolkitName": "PC Doctor Portable",
    "Language": "EN",
    "Theme": "System",
    "ShowToast": true,
    "ConsoleStyle": "Classic"
  },
  "Cleanup": {
    "CleanTemp": true,
    "CleanBrowserCache": true,
    "CleanCookies": true,
    "CleanPrefetch": true,
    "CleanCrashDumps": true
  },
  "Repair": {
    "RunDISM": true,
    "RunSFC": true
  }
}
```

---

## 🔄 Auto-Update

The app checks GitHub Releases for new versions. To enable:

1. Set `UpdateUrl` in `Config.json` to your releases API
2. The GUI will show a "Download Now" button when updates are available

---

## 📅 Scheduled Runs

Register a weekly auto-run via Windows Task Scheduler:

**GUI:** Settings → Register in Windows Task Scheduler

**Console:** The app prompts after first run.

The task runs with highest privileges and shows a toast notification on completion.

---

## 🌐 Localization

- **English** — Full support
- **Hindi (हिंदी)** — Full support with Devanagari script

Switch languages in Settings or edit `Config.json`.

---

## 🛡️ Security Notes

### ⚠️ IMPORTANT — NO WARRANTY

> **This software is provided "AS IS" without warranty of any kind.**
> 
> PC Doctor Portable performs system maintenance operations including file deletion, system repairs, and driver updates. While every effort has been made to ensure safety:
> 
> - **Always create a restore point** before running (the app does this automatically by default)
> - **Back up important data** before using maintenance features
> - **Test in a non-production environment** first if possible
> - **The authors are NOT responsible** for any data loss, system damage, or other issues that may arise from using this software
> 
> See [LICENSE.txt](LICENSE.txt) for the full MIT License including the "NO WARRANTY" clause.

### Code Signing

For production distribution, sign the installer with a code-signing certificate:

```powershell
# Generate a test certificate
pwsh -File Tools\New-SignedCert.ps1

# Sign the installer
pwsh -File Tools\Sign-Installer.ps1 -PfxPath "Assets\PCDoctorCert.pfx" -PfxPassword "PCDoctor2026!"
```

> **Note:** Self-signed certificates still trigger SmartScreen warnings. For trusted publisher status, use a certificate from a public CA (DigiCert, Sectigo, etc.).

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Run tests: `pwsh -File Tools\Run-Tests.ps1`
4. Submit a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see [LICENSE.txt](LICENSE.txt) for details.

```
MIT License

Copyright (c) 2026 Code Knot Technology

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🙏 Acknowledgments

- Built with **PowerShell** and **WPF**
- Installer by **Inno Setup**
- CI/CD by **GitHub Actions**
- Icons: **Segoe MDL2 Assets**

---

<div align="center">

**Made with ❤️ by Code Knot Technology**

*Keep your PC healthy, automatically.*

</div>
