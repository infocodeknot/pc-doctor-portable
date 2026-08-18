; ==========================================================
; PC Doctor Portable - Inno Setup Installer Script
; Code Knot Technology
;
; Build with Inno Setup 6:
;   ISCC.exe PCDoctorPortable.iss
; or run Tools\Build-Installer.ps1 (auto-detects ISCC).
; ==========================================================

#define MyAppName "PC Doctor Portable"
#define MyAppVersion "1.2"
#define MyAppPublisher "Code Knot Technology"
#define MyAppURL "https://www.codeknot.com"
#define MainPSScript "{app}\App\PCDoctor-GUI.ps1"
#define PSExe "{sys}\WindowsPowerShell\v1.0\powershell.exe"

[Setup]
; NOTE: the AppId value uniquely identifies this app.
AppId={{2D922DE4-B406-452E-AF83-B444347BDAA7}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\PC Doctor Portable
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir=Output
OutputBaseFilename=PCDoctorPortable-Setup-{#MyAppVersion}
SetupIconFile=..\Assets\PCDoctor.ico
UninstallDisplayIcon={app}\Assets\PCDoctor.ico
UninstallDisplayName={#MyAppName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
VersionInfoVersion=1.2.0.0
VersionInfoCompany=Code Knot Technology
VersionInfoDescription=PC Doctor Portable Setup
VersionInfoProductName=PC Doctor Portable
VersionInfoProductVersion=1.2.0.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\Main.ps1";                    DestDir: "{app}"; Flags: ignoreversion
Source: "..\Run.bat";                     DestDir: "{app}"; Flags: ignoreversion
Source: "..\Config.json";                 DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.txt";                  DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE.txt";                 DestDir: "{app}"; Flags: ignoreversion
Source: "..\Assets\README_HINDI.txt";     DestDir: "{app}"; Flags: ignoreversion
Source: "..\Modules\*.ps1";               DestDir: "{app}\Modules"; Flags: ignoreversion
Source: "..\Assets\*";                    DestDir: "{app}\Assets"; Flags: ignoreversion
Source: "..\App\*";                       DestDir: "{app}\App"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{#PSExe}"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{#MainPSScript}"""; WorkingDir: "{app}"; IconFilename: "{app}\Assets\PCDoctor.ico"
Name: "{group}\{#MyAppName} (Console)"; Filename: "{app}\Run.bat"; IconFilename: "{app}\Assets\PCDoctor.ico"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{#PSExe}"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{#MainPSScript}"""; WorkingDir: "{app}"; IconFilename: "{app}\Assets\PCDoctor.ico"; Tasks: desktopicon

[UninstallDelete]
Type: filesandordirs; Name: "{app}\Logs"
Type: filesandordirs; Name: "{app}\Reports"
Type: filesandordirs; Name: "{app}\Backups"
Type: filesandordirs; Name: "{app}\Tests"
Type: filesandordirs; Name: "{app}\Tools"
Type: filesandordirs; Name: "{app}\.github"
Type: filesandordirs; Name: "{app}\.freebuff"
Type: filesandordirs; Name: "{app}\Installer"
Type: filesandordirs; Name: "{localappdata}\PCDoctorPortable"
Type: filesandordirs; Name: "{userappdata}\PCDoctorPortable"

[UninstallRun]
Filename: "{#PSExe}"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command Stop-ScheduledTask -TaskName PCDoctorPortable -ErrorAction SilentlyContinue"; Flags: runhidden
Filename: "{#PSExe}"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command Unregister-ScheduledTask -TaskName PCDoctorPortable -Confirm:`$false -ErrorAction SilentlyContinue"; Flags: runhidden

[Run]
Filename: "{#PSExe}"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{#MainPSScript}"""; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
