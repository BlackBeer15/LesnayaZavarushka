;_Inno Setup script for Lesnaya Zavarushka (optional, used by build_release.ps1)

#define AppName "Lesnaya Zavarushka"
#define AppVersion "0.1.0"
#define AppExe "LesnayaZavarushka.exe"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=BlackBeer15
DefaultDirName={pf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir=build
OutputBaseFilename=LesnayaZavarushka_setup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\{#AppExe}

[Files]
Source: "build\windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Uninstall"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
