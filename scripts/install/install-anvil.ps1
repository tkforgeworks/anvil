# install-anvil.ps1: install or update Anvil (0.2.0 and later) on Windows from
# a GitHub release of tkforgeworks/anvil (ANVL-143).
#
# Resolves a release through GitHub's public REST API (no token, no gh),
# downloads anvil-<ver>-windows-x64-setup.exe, checks it against the sha256
# digest GitHub publishes for it, and runs the Inno Setup installer silently,
# waiting for it and reporting its exit code. Run it again to update. The
# installer replaces an Anvil 0.1.x (Electron) install of the same scope;
# 0.1.x counts as older. 0.1.x releases themselves have no asset this script
# installs.
#
# Usage: install-anvil.ps1 [[-Tag] <tag>] [-Stable] [-Check] [-AllUsers]
#                          [-InstallDir <dir>] [-Help]
#   (no option)  newest release, release candidates included
#   -Stable      newest stable release
#   -Tag         that release, e.g. v0.2.0 or v0.2.0-rc.1; may downgrade
#   -Check       print the resolved release and the installed version, and
#                exit without changing anything
#   -AllUsers    install for all users (Program Files); needs an elevated
#                PowerShell. Without it the install is per user
#                (%LOCALAPPDATA%\Programs\Anvil), except that an existing
#                all-users install is updated in place (also elevated).
#   -InstallDir  install into this folder (Setup's /DIR=); an update keeps
#                the folder of the existing install unless this is given
#   -Help        show this help
# Without -Tag it never downgrades: when the installed Anvil is newer than the
# resolved release it says so and exits 0.
#
# Running Anvil: Setup runs /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
# /CLOSEAPPLICATIONS /NORESTARTAPPLICATIONS. If Anvil is open, Setup asks it to
# close through the Windows Restart Manager, as an app is asked at sign-out;
# it does not force-close it (/FORCECLOSEAPPLICATIONS is not passed, since
# that would drop unsaved edits) and does not start it again afterwards. If
# Anvil does not close, for example while it shows its unsaved-changes prompt,
# Setup cannot replace its files and fails, and this script reports Setup's
# exit code. Close Anvil and run the script again.
#
# Environment:
#   ANVIL_RELEASES_API  base URL of the releases API, default
#                       https://api.github.com/repos/tkforgeworks/anvil.
#                       A testing aid: point it at a fake release.
#
# Runs on Windows PowerShell 5.1 and PowerShell 7. Piped use:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/tkforgeworks/anvil/main/scripts/install/install-anvil.ps1))) -Stable
# Dot-sourcing it (. .\install-anvil.ps1) defines the functions and installs
# nothing; scripts/install/test/test-install-anvil.ps1 does that.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
    Justification = 'Interactive installer: status lines go to the console, not the pipeline.')]
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Tag,
    [switch]$Stable,
    [switch]$Check,
    [switch]$AllUsers,
    [string]$InstallDir,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:DefaultApi = 'https://api.github.com/repos/tkforgeworks/anvil'
# Inno writes "<AppId>_is1"; AppId is in windows/installer/anvil.iss.
$script:InnoKeyName = '{C4D7B55B-5739-4101-B405-A93BF69507B4}_is1'
# electron-builder's key for 0.1.x (see PrepareToInstall in anvil.iss).
$script:ElectronKeyName = '268ba5f3-2477-54c8-a960-331b2ce83d97'

$script:UsageText = @'
install-anvil.ps1: install or update Anvil (0.2.0 and later) from a GitHub release.

Usage: install-anvil.ps1 [[-Tag] <tag>] [-Stable] [-Check] [-AllUsers] [-InstallDir <dir>] [-Help]

  (no option)  newest release, release candidates included
  -Stable      newest stable release
  -Tag         that release, e.g. v0.2.0 or v0.2.0-rc.1; may downgrade
  -Check       print the resolved release and the installed version, change nothing
  -AllUsers    install for all users (needs an elevated PowerShell)
  -InstallDir  install into this folder
  -Help        show this help

Downloads anvil-<version>-windows-x64-setup.exe, checks its sha256 against the
digest GitHub publishes, and runs it silently (per user unless -AllUsers or an
existing all-users install). Without -Tag it never downgrades. Run it again to
update.

If Anvil is running, Setup asks it to close (Windows Restart Manager) and does
not restart it; it never force-closes it. If Anvil stays open, Setup fails and
the script reports the exit code: close Anvil and run the script again.

Environment:
  ANVIL_RELEASES_API  releases API base URL (testing aid), default
                      https://api.github.com/repos/tkforgeworks/anvil

Piped:
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/tkforgeworks/anvil/main/scripts/install/install-anvil.ps1))) -Stable
'@

# --- Pure functions (the test file dot-sources the script to reach these) ---

function ConvertTo-AnvilVersion {
    # 'X.Y.Z' or 'X.Y.Z-rc.N', with or without a leading v, to an object with
    # Major/Minor/Patch/Rc (Rc = [int]::MaxValue for a stable release, so it
    # sorts above every rc of the same X.Y.Z); $null for anything else.
    param([AllowNull()][AllowEmptyString()][string]$Version)
    if (-not $Version) { return $null }
    $m = [regex]::Match($Version, '^v?(\d+)\.(\d+)\.(\d+)(?:-rc\.(\d+))?$')
    if (-not $m.Success) { return $null }
    $rc = [int]::MaxValue
    if ($m.Groups[4].Success) { $rc = [int]$m.Groups[4].Value }
    return [pscustomobject]@{
        Major = [int]$m.Groups[1].Value
        Minor = [int]$m.Groups[2].Value
        Patch = [int]$m.Groups[3].Value
        Rc    = $rc
    }
}

function Compare-AnvilVersion {
    # -1, 0 or 1 for A against B. An A that is not X.Y.Z[-rc.N] counts as
    # older; a B that is not throws.
    param([AllowNull()][AllowEmptyString()][string]$A, [string]$B)
    $vb = ConvertTo-AnvilVersion $B
    if ($null -eq $vb) { throw "Not a release version: '$B'" }
    $va = ConvertTo-AnvilVersion $A
    if ($null -eq $va) { return -1 }
    foreach ($part in 'Major', 'Minor', 'Patch', 'Rc') {
        if ($va.$part -lt $vb.$part) { return -1 }
        if ($va.$part -gt $vb.$part) { return 1 }
    }
    return 0
}

function Get-JsonProperty {
    # A property of a JSON object, or $Default when it is missing (StrictMode
    # throws on a missing property).
    param($Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    return $p.Value
}

function Select-AnvilRelease {
    # The first release of -Releases (newest first, as GitHub lists them) that
    # is not a draft and matches: -Tag that tag, -Stable not a prerelease,
    # neither the newest. $null when none does.
    param([object[]]$Releases, [string]$Tag, [switch]$Stable)
    foreach ($r in $Releases) {
        if ($null -eq $r) { continue }
        if (Get-JsonProperty $r 'draft' $false) { continue }
        if ($Stable -and (Get-JsonProperty $r 'prerelease' $false)) { continue }
        if ($Tag -and ((Get-JsonProperty $r 'tag_name' '') -ne $Tag)) { continue }
        return $r
    }
    return $null
}

function Get-AnvilAssetName {
    param([string]$Tag)
    $version = $Tag
    if ($version.StartsWith('v')) { $version = $version.Substring(1) }
    return "anvil-$version-windows-x64-setup.exe"
}

function Find-AnvilAsset {
    # The asset of -Release named -Name, or $null.
    param($Release, [string]$Name)
    foreach ($a in @(Get-JsonProperty $Release 'assets' @())) {
        if ($null -ne $a -and (Get-JsonProperty $a 'name' '') -ceq $Name) { return $a }
    }
    return $null
}

function Get-ExpectedSha256 {
    # The hex sha256 from an asset's "sha256:<hex>" digest; '' when GitHub
    # lists none, $null when it uses another algorithm.
    param($Asset)
    $digest = [string](Get-JsonProperty $Asset 'digest' '')
    if (-not $digest) { return '' }
    if ($digest -match '^sha256:([0-9a-fA-F]{64})$') { return $Matches[1].ToLowerInvariant() }
    return $null
}

function Get-InstallerArgumentString {
    # Setup's command line. -Scope is AllUsers or CurrentUser.
    param([string]$Scope, [string]$InstallDir, [string]$LogPath)
    $parts = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
        '/CLOSEAPPLICATIONS', '/NORESTARTAPPLICATIONS')
    if ($Scope -eq 'AllUsers') { $parts += '/ALLUSERS' } else { $parts += '/CURRENTUSER' }
    if ($InstallDir) { $parts += ('/DIR="' + $InstallDir.TrimEnd('\') + '"') }
    if ($LogPath) { $parts += ('/LOG="' + $LogPath + '"') }
    return ($parts -join ' ')
}

function Get-SetupExitMeaning {
    param([int]$Code)
    switch ($Code) {
        1 { return 'Setup failed to initialize' }
        2 { return 'cancelled before the installation started' }
        3 { return 'fatal error while preparing the next installation phase' }
        4 { return 'fatal error during the installation' }
        5 { return 'cancelled during the installation, or a file could not be replaced (is Anvil still open?)' }
        6 { return 'Setup was terminated' }
        7 { return 'Setup determined it cannot proceed (for example the 0.1.x uninstaller failed)' }
        8 { return 'Setup cannot proceed until Windows restarts' }
        default { return 'unknown exit code' }
    }
}

# --- Host functions (registry, network, processes) ---

function Get-UninstallEntry {
    # The DisplayVersion and InstallLocation under an uninstall key name, from
    # HKCU, then HKLM (64-bit and 32-bit views); $null when none has it.
    param([string]$KeyName)
    $roots = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'; Scope = 'CurrentUser' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'; Scope = 'AllUsers' },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'; Scope = 'AllUsers' }
    )
    foreach ($root in $roots) {
        $key = Join-Path $root.Path $KeyName
        if (-not (Test-Path -LiteralPath $key)) { continue }
        $item = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        $version = [string](Get-JsonProperty $item 'DisplayVersion' '')
        if (-not $version) { continue }
        return [pscustomobject]@{
            Version  = $version
            Scope    = $root.Scope
            Location = [string](Get-JsonProperty $item 'InstallLocation' '')
        }
    }
    return $null
}

function Test-Elevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-AnvilApi {
    # The parsed JSON at $Url, or $null on HTTP 404.
    param([string]$Url)
    try {
        # No Accept header: 5.1 refuses it in -Headers, and GitHub's default
        # is the same JSON.
        return Invoke-RestMethod -Uri $Url -UseBasicParsing
    } catch {
        $status = 0
        $response = Get-JsonProperty $_.Exception 'Response'
        if ($null -ne $response) { $status = [int](Get-JsonProperty $response 'StatusCode' 0) }
        if ($status -eq 404) { return $null }
        if ($status -eq 403 -or $status -eq 429) {
            throw "The GitHub API refused the request (HTTP $status). Without a token it allows 60 requests an hour; try again later."
        }
        throw "Could not read $Url : $($_.Exception.Message)"
    }
}

function Invoke-AnvilInstall {
    param([string]$Tag, [switch]$Stable, [switch]$Check, [switch]$AllUsers, [string]$InstallDir)

    if ($Tag -and $Stable) { throw 'Give either -Stable or -Tag, not both.' }
    $onWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    if (-not $onWindows) { throw 'install-anvil.ps1 installs the Windows build; on Linux use install-anvil.sh.' }
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Anvil is built for 64-bit Windows only.' }

    $mode = 'newest'
    if ($Tag) {
        if (-not $Tag.StartsWith('v')) { $Tag = 'v' + $Tag }
        if ($null -eq (ConvertTo-AnvilVersion $Tag)) { throw "'$Tag' is not a release tag (vX.Y.Z or vX.Y.Z-rc.N)." }
        $mode = 'tag'
    } elseif ($Stable) {
        $mode = 'stable'
    }

    if ($PSVersionTable.PSEdition -ne 'Core') {
        # Windows PowerShell 5.1 may default to TLS 1.0/1.1, which GitHub refuses.
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }

    $api = $env:ANVIL_RELEASES_API
    if (-not $api) { $api = $script:DefaultApi }
    $api = $api.TrimEnd('/')
    switch ($mode) {
        'newest' { $url = "$api/releases?per_page=100" }
        'stable' { $url = "$api/releases/latest" }
        default { $url = "$api/releases/tags/$Tag" }
    }
    $data = Invoke-AnvilApi $url
    if ($null -eq $data) {
        if ($mode -eq 'tag') { throw "There is no published release tagged $Tag." }
        if ($mode -eq 'stable') { throw 'There is no stable release yet; run without -Stable for the newest release candidate.' }
        throw "The releases API returned 404 for $url"
    }
    $release = Select-AnvilRelease -Releases @($data) -Tag $Tag -Stable:($mode -eq 'stable')
    if ($null -eq $release) {
        if ($mode -eq 'tag') { throw "There is no published release tagged $Tag (drafts are never installed)." }
        throw 'No published release found.'
    }
    $Tag = [string](Get-JsonProperty $release 'tag_name' '')
    $version = $Tag.TrimStart('v')
    $isPrerelease = [bool](Get-JsonProperty $release 'prerelease' $false)
    $assetName = Get-AnvilAssetName $Tag
    $asset = $null
    if ($null -ne (ConvertTo-AnvilVersion $version)) { $asset = Find-AnvilAsset $release $assetName }

    $installed = Get-UninstallEntry $script:InnoKeyName
    $electron = Get-UninstallEntry $script:ElectronKeyName
    $current = $null
    if ($null -ne $installed) { $current = $installed } elseif ($null -ne $electron) { $current = $electron }

    $kind = 'stable'
    if ($isPrerelease) { $kind = 'release candidate' }
    Write-Host "Release:   $Tag ($kind)"
    if ($null -ne $installed) {
        Write-Host "Installed: $($installed.Version) ($($installed.Scope), $($installed.Location))"
    } else {
        Write-Host 'Installed: not installed'
    }
    if ($null -ne $electron) {
        $note = 'Setup removes it first; app data and projects are kept.'
        if ($electron.Scope -eq 'AllUsers' -and -not $AllUsers -and ($null -eq $installed -or $installed.Scope -ne 'AllUsers')) {
            $note = 'A per-user install leaves it side by side; remove it from Settings > Apps, or use -AllUsers from an elevated PowerShell to replace it.'
        }
        Write-Host "Older:     Anvil $($electron.Version) (0.1.x, $($electron.Scope)). $note"
    }

    if ($null -eq $asset) {
        throw ("Release $Tag has no $assetName, so there is nothing for Windows to install. Releases before 0.2.0 are " +
            'Electron builds this script does not handle; get them from https://github.com/tkforgeworks/anvil/releases.')
    }

    $action = 'install'
    if ($null -ne $current) {
        $cmp = Compare-AnvilVersion $current.Version $version
        if ($cmp -eq 0) { $action = 'current' }
        elseif ($cmp -lt 0) { $action = 'upgrade' }
        elseif ($mode -eq 'tag') { $action = 'downgrade' }
        else { $action = 'newer' }
    }

    if ($Check) {
        switch ($action) {
            'install' { Write-Host "Action:    would install $version" }
            'upgrade' { Write-Host "Action:    would upgrade $($current.Version) to $version" }
            'downgrade' { Write-Host "Action:    would downgrade $($current.Version) to $version" }
            'current' { Write-Host 'Action:    none, already up to date' }
            'newer' { Write-Host "Action:    none, the installed $($current.Version) is newer (pass -Tag to downgrade)" }
        }
        return
    }
    if ($action -eq 'current') { Write-Host "Anvil $version is already up to date."; return }
    if ($action -eq 'newer') {
        Write-Host "The installed Anvil $($current.Version) is newer than $Tag; not downgrading. To install $Tag anyway, pass it: -Tag $Tag"
        return
    }

    $scope = 'CurrentUser'
    if ($AllUsers) {
        $scope = 'AllUsers'
    } elseif ($null -ne $installed -and $installed.Scope -eq 'AllUsers') {
        $scope = 'AllUsers'
        Write-Host 'Anvil is installed for all users, so the update is too.'
    }
    if ($scope -eq 'AllUsers' -and -not (Test-Elevated)) {
        throw 'An all-users install needs an elevated PowerShell: right-click PowerShell, choose Run as administrator, and run this again.'
    }

    $running = @(Get-Process -Name 'anvil' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        Write-Warning 'Anvil is running. Setup will ask it to close and will not restart it; save your work first. If it stays open, Setup fails.'
    }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('anvil-install-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $logPath = Join-Path ([IO.Path]::GetTempPath()) "anvil-setup-$version.log"
    $succeeded = $false
    try {
        $file = Join-Path $tmp $assetName
        $downloadUrl = [string](Get-JsonProperty $asset 'browser_download_url' '')
        Write-Host "Downloading $assetName"
        $savedProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'   # 5.1 downloads very slowly while drawing progress
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $file -UseBasicParsing
        } finally {
            $ProgressPreference = $savedProgress
        }

        $expected = Get-ExpectedSha256 $asset
        if ($null -eq $expected) {
            Write-Warning "GitHub lists a digest this script cannot check for $assetName; the download is not verified."
        } elseif ($expected -eq '') {
            Write-Warning "GitHub lists no digest for $assetName, so the download cannot be verified."
        } else {
            $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actual -ne $expected) {
                throw "sha256 mismatch for ${assetName}: GitHub lists $expected, the download is $actual. Nothing was installed."
            }
            Write-Host 'sha256 verified.'
        }

        switch ($action) {
            'install' { Write-Host "Installing Anvil $version ($scope)" }
            'upgrade' { Write-Host "Upgrading Anvil $($current.Version) to $version ($scope)" }
            'downgrade' { Write-Host "Downgrading Anvil $($current.Version) to $version ($scope)" }
        }
        $arguments = Get-InstallerArgumentString -Scope $scope -InstallDir $InstallDir -LogPath $logPath
        $process = Start-Process -FilePath $file -ArgumentList $arguments -Wait -PassThru
        $code = $process.ExitCode
        Write-Host "Setup exit code: $code"
        if ($code -ne 0) {
            throw "Setup failed with exit code $code ($(Get-SetupExitMeaning $code)). Its log is $logPath"
        }
        $succeeded = $true
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        if ($succeeded) { Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue }
    }

    $after = Get-UninstallEntry $script:InnoKeyName
    if ($null -eq $after -or (Compare-AnvilVersion $after.Version $version) -ne 0) {
        $seen = 'none'
        if ($null -ne $after) { $seen = $after.Version }
        throw "Setup reported success, but the installed version is $seen, not $version."
    }
    Write-Host "Anvil $version is installed in $($after.Location)."
}

# --- Main (skipped when dot-sourced) ---

if ($MyInvocation.InvocationName -ne '.') {
    if ($Help) {
        Write-Output $script:UsageText
    } else {
        try {
            Invoke-AnvilInstall -Tag $Tag -Stable:$Stable -Check:$Check -AllUsers:$AllUsers -InstallDir $InstallDir
        } catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            # Run as a .ps1 file, exit 1 ends just the script. Run as a script
            # block (the irm one-liner), exit would close the user's
            # PowerShell window or end the caller's script, so only set the
            # exit code. ($PSCommandPath cannot tell them apart: a script
            # block sees its caller's.)
            if ($MyInvocation.MyCommand.CommandType -eq [System.Management.Automation.CommandTypes]::ExternalScript) { exit 1 }
            $global:LASTEXITCODE = 1
        }
    }
}
