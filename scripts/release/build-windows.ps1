#Requires -Version 7
<#
.SYNOPSIS
  Builds the Windows release bundle, the Inno Setup installer and a plain zip
  into release/.

.DESCRIPTION
  The release-flutter.yml contract (tkforgeworks/.github): run on
  windows-latest from the repo root after subosito/flutter-action, leave
  release/*.exe (and optionally release/*.zip) behind. Modelled on
  lazy-sleeper-app's script (LS-73), the first Windows installer through the
  org pipeline.

  Steps: flutter build windows --release → copy the VC++ runtime DLLs into
  the bundle (Flutter does not ship them; without them a clean machine gets
  "VCRUNTIME140.dll was not found") → ISCC windows/installer/anvil.iss →
  zip the bundle. The version comes from pubspec.yaml: X.Y.Z[-rc.N]+BUILD
  becomes the installer version X.Y.Z[-rc.N].

  Output:
    release/anvil-<version>-windows-x64-setup.exe   the installer
    release/anvil-<version>-windows-x64.zip         the bundle, unpacked use

  Needs Inno Setup 6 (on the windows-latest image; locally
  winget install JRSoftware.InnoSetup) and a Visual Studio install with the
  C++ desktop workload (which flutter build needs anyway).

.PARAMETER SkipFlutterBuild
  Reuse build/windows from a previous run; just package.
#>
[CmdletBinding()]
param([switch]$SkipFlutterBuild)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$appVersion = $version.Split('+')[0]
Write-Host "Anvil $version → installer version $appVersion"

if (-not $SkipFlutterBuild) {
    flutter build windows --release
    if ($LASTEXITCODE) { throw "flutter build windows failed ($LASTEXITCODE)" }
}

# BINARY_NAME in windows/CMakeLists.txt.
$bundle = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $bundle 'anvil.exe'))) {
    throw "No release bundle at $bundle"
}

# VC++ runtime from the newest VS redist on this machine.
$crt = Get-ChildItem "${env:ProgramFiles}\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC14?.CRT" `
    -Directory -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
if ($crt) {
    foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
        Copy-Item (Join-Path $crt.FullName $dll) $bundle -Force
    }
    Write-Host "VC++ runtime copied from $($crt.FullName)"
} else {
    Write-Warning 'No VC++ redist found under Visual Studio; the app will need vc_redist.x64.exe on a clean machine.'
}

$iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 not found. Install it: winget install JRSoftware.InnoSetup' }

$release = Join-Path $root 'release'
New-Item -ItemType Directory -Force $release | Out-Null

& $iscc /Q "/DAppVersion=$appVersion" "/DSourceDir=$bundle" (Join-Path $root 'windows\installer\anvil.iss')
if ($LASTEXITCODE) { throw "ISCC failed ($LASTEXITCODE)" }

$zip = Join-Path $release "anvil-$appVersion-windows-x64.zip"
Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $zip -Force

Get-ChildItem $release -Filter "anvil-$appVersion-windows*" |
    Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }
