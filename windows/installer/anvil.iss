; Anvil — Windows installer (Inno Setup 6).
;
; The Flutter replacement for 0.1.x's electron-builder NSIS "assisted"
; installer (oneClick: false), following lazy-sleeper-app's installer
; (LS-73): a wizard with a per-user / all-users choice, an install-directory
; page, a Start Menu shortcut and a desktop shortcut (a task, checked by
; default), and an uninstaller that removes the program files, shortcuts and
; uninstall entry but leaves app data and project files alone. Built by
; scripts/release/build-windows.ps1, which passes
; /DAppVersion=<pubspec version without +BUILD> and
; /DSourceDir=<flutter release bundle>. Run ISCC by hand only with both
; defines set.
;
; Upgrading over Anvil 0.1.x (Electron). Inno's uninstall key is
; "<AppId>_is1", which can never match electron-builder's, and both default
; to the same folder (%LOCALAPPDATA%\Programs\Anvil per user,
; Program Files\Anvil for all users), so installing over 0.1.x without help
; would mix Electron and Flutter files in one folder under two "Anvil"
; entries in Apps. PrepareToInstall below therefore finds the 0.1.x install
; through electron-builder's registry keys and runs its uninstaller silently
; first, the way electron-builder's own installer removes an old version:
; the result is a replacement, with one "Anvil" entry left. App data
; (%APPDATA%\Anvil) is kept, as is every .anvil project file.

#ifndef AppVersion
  #error Pass /DAppVersion=x.y.z (scripts/release/build-windows.ps1 does)
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#define AppName "Anvil"
; BINARY_NAME in windows/CMakeLists.txt.
#define AppExe "anvil.exe"
#define Publisher "TK ForgeWorks"

[Setup]
; Stable per app: Windows uses it to recognise upgrades. Never change it.
AppId={{C4D7B55B-5739-4101-B405-A93BF69507B4}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#Publisher}
AppPublisherURL=https://github.com/tkforgeworks/anvil
AppSupportURL=https://github.com/tkforgeworks/anvil/issues
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}
; {autopf} is Program Files for an all-users install and
; %LOCALAPPDATA%\Programs for the current user only: the same folders
; electron-builder used for 0.1.x.
DefaultDirName={autopf}\{#AppName}
; The one shortcut goes straight into the Start Menu's Programs folder
; ({autoprograms}), where 0.1.x put it, so there is no group page; the group
; name is set only because Inno expects one.
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Per-user by default, as 0.1.x was; the wizard offers all-users (elevating).
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\release
OutputBaseFilename=anvil-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Unsigned: SmartScreen will warn on first run ("More info" → "Run anyway").

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  // electron-builder's APP_GUID for 0.1.x: UUID v5 of the appId
  // com.tkforgeworks.anvil in its namespace 50e065bc-3134-11e6-9bab-38c9862bdaf3
  // (app-builder-lib 26.15.7, NsisTarget). Its installer wrote
  // UninstallString '"<dir>\Uninstall Anvil.exe" /currentuser|/allusers'
  // under the uninstall key and InstallLocation under Software\<guid>, in
  // HKCU for a per-user install and in HKLM (64-bit view) for all users.
  ElectronUninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\268ba5f3-2477-54c8-a960-331b2ce83d97';
  ElectronInstallKey = 'Software\268ba5f3-2477-54c8-a960-331b2ce83d97';

// Runs the 0.1.x uninstaller found under RootKey, silently and to the end.
// Returns '' when there was nothing to remove or it was removed, else the
// message that stops setup (installing over a half-removed Electron folder
// would leave a broken mix).
function RemoveElectronInstall(RootKey: Integer; Scope: String): String;
var
  UninstallString, Uninstaller, Dir, TempCopy: String;
  Rest: String;
  ResultCode: Integer;
begin
  Result := '';
  if not RegQueryStringValue(RootKey, ElectronUninstallKey, 'UninstallString', UninstallString) then
    Exit;

  // '"C:\...\Uninstall Anvil.exe" /currentuser' gives the quoted path.
  Uninstaller := UninstallString;
  if Copy(Uninstaller, 1, 1) = '"' then
  begin
    Rest := Copy(Uninstaller, 2, Length(Uninstaller) - 1);
    Uninstaller := Copy(Rest, 1, Pos('"', Rest) - 1);
  end;
  if not FileExists(Uninstaller) then
  begin
    Log('Anvil 0.1.x uninstall entry points at a missing file, skipping: ' + UninstallString);
    Exit;
  end;
  if not RegQueryStringValue(RootKey, ElectronInstallKey, 'InstallLocation', Dir) or (Dir = '') then
    Dir := ExtractFileDir(Uninstaller);

  Log('Removing Anvil 0.1.x (' + Scope + ') from ' + Dir);
  // Run a copy from {tmp} with _?= so it works in place and waits; the
  // original deletes the whole folder, itself included. _?= must come last
  // and unquoted, even with spaces in the path.
  TempCopy := ExpandConstant('{tmp}\anvil-0.1-uninstaller.exe');
  if not FileCopy(Uninstaller, TempCopy, False) then
    TempCopy := Uninstaller;
  if not Exec(TempCopy, '/S /KEEP_APP_DATA ' + Scope + ' _?=' + Dir, '', SW_HIDE,
      ewWaitUntilTerminated, ResultCode) or (ResultCode <> 0) then
  begin
    Result := 'Setup could not remove the previous version of Anvil (0.1, ' + Dir + '). ' +
      'Uninstall it from Settings > Apps > Installed apps, then run this setup again. ' +
      'Your projects and settings are not affected.';
    Log('Anvil 0.1.x uninstaller failed, result ' + IntToStr(ResultCode));
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  // The current user's 0.1.x install is always replaced. An all-users 0.1.x
  // install needs admin rights to remove, so it is replaced only by an
  // all-users install; a per-user 0.2 install leaves it side by side in its
  // own Program Files folder.
  Result := RemoveElectronInstall(HKEY_CURRENT_USER, '/currentuser');
  if (Result = '') and IsAdminInstallMode then
    Result := RemoveElectronInstall(HKLM64, '/allusers');
  if (Result = '') and IsAdminInstallMode then
    Result := RemoveElectronInstall(HKLM32, '/allusers');
end;
