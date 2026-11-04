# Tests for install-anvil.ps1 that run without Windows (ANVL-143):
#   - the script parses, and uses no PowerShell 7-only syntax (so it still
#     parses on Windows PowerShell 5.1)
#   - -Help prints the usage, run as a file and as a script block (the irm
#     one-liner's form)
#   - a non-Windows run fails with a clear message: exit code 1 as a file,
#     $LASTEXITCODE = 1 and no session exit as a script block
#   - the pure functions, dot-sourced, against make-fake-release.py's JSON:
#     release choice, version order, asset choice and digest, Setup arguments
#   - with -Analyze, PSScriptAnalyzer's findings (printed, not failing)
# Usage: pwsh -File test-install-anvil.ps1 -FakeDir <make-fake-release.py --out> [-Analyze]
# run-container-tests.sh pwsh runs it in mcr.microsoft.com/powershell.
param(
    [Parameter(Mandatory = $true)][string]$FakeDir,
    [switch]$Analyze
)
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Join-Path $PSScriptRoot '..') 'install-anvil.ps1'
$script:failures = 0

function Assert-That {
    param([string]$Description, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        Write-Host "PASS  $Description"
    } else {
        $script:failures++
        Write-Host "FAIL  $Description $Detail"
    }
}

function Read-Json([string]$RelativePath) {
    return (Get-Content -Raw -LiteralPath (Join-Path $FakeDir $RelativePath) | ConvertFrom-Json)
}

# --- Parse, and no 7-only syntax ---
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors) | Out-Null
Assert-That 'install-anvil.ps1 parses with no errors' ($errors.Count -eq 0) (($errors | ForEach-Object { $_.Message }) -join '; ')
$sevenOnly = @('QuestionQuestion', 'QuestionQuestionEquals', 'QuestionDot', 'QuestionLBracket', 'AndAnd', 'OrOr', 'QuestionMark')
$found = @($tokens | Where-Object { $sevenOnly -contains $_.Kind.ToString() } | ForEach-Object { "$($_.Kind) at line $($_.Extent.StartLineNumber)" })
Assert-That 'no ?? ?. ?[ && || or ternary (5.1 cannot parse them)' ($found.Count -eq 0) ($found -join ', ')
$text = Get-Content -Raw -LiteralPath $scriptPath
Assert-That 'no ForEach-Object -Parallel, ConvertFrom-Json -AsHashtable/-Depth, or $IsWindows' (
    -not ($text -match '-Parallel|-AsHashtable|ConvertFrom-Json\s+-Depth|\$IsWindows'))

# --- -Help ---
$help = (& pwsh -NoProfile -NonInteractive -File $scriptPath -Help) -join "`n"
Assert-That '-Help as a file prints the usage' ($help -match 'Usage: install-anvil.ps1') $help
Assert-That '-Help as a file exits 0' ($LASTEXITCODE -eq 0) "exit $LASTEXITCODE"
$block = [scriptblock]::Create($text)
$blockHelp = (& $block -Help) -join "`n"
Assert-That '-Help as a script block prints the usage' ($blockHelp -match 'Usage: install-anvil.ps1')

# --- Non-Windows run ---
$fileRun = (& pwsh -NoProfile -NonInteractive -File $scriptPath -Check *>&1) -join "`n"
Assert-That 'a run off Windows exits 1 as a file' ($LASTEXITCODE -eq 1) "exit $LASTEXITCODE"
Assert-That 'a run off Windows says to use install-anvil.sh' ($fileRun -match 'install-anvil\.sh') $fileRun
$global:LASTEXITCODE = 0
& $block -Check *> $null
Assert-That 'a script-block run off Windows sets LASTEXITCODE 1 and returns' ($LASTEXITCODE -eq 1) "exit $LASTEXITCODE"

# --- Pure functions ---
. $scriptPath
Assert-That 'dot-sourcing defines the functions and installs nothing' ($null -ne (Get-Command Select-AnvilRelease -ErrorAction SilentlyContinue))

$list = Read-Json 'api/releases/index.html'
$oldList = Read-Json 'api-old/releases/index.html'
$latest = Read-Json 'api/releases/latest'
$v020 = Read-Json 'api/releases/tags/v0.2.0'
$v016 = Read-Json 'api/releases/tags/v0.1.6'
$draft = Read-Json 'api/releases/tags/v0.3.0'

Assert-That 'the list starts with the draft v0.3.0' (@($list)[0].tag_name -eq 'v0.3.0' -and @($list)[0].draft)
$r = Select-AnvilRelease -Releases @($list)
Assert-That 'default: newest non-draft is v0.2.0 (draft v0.3.0 skipped)' ($r.tag_name -eq 'v0.2.0') $r.tag_name
$r = Select-AnvilRelease -Releases @($list) -Stable
Assert-That '-Stable over the list: v0.2.0' ($r.tag_name -eq 'v0.2.0') $r.tag_name
$r = Select-AnvilRelease -Releases @($latest) -Stable
Assert-That '-Stable over releases/latest: v0.2.0' ($r.tag_name -eq 'v0.2.0') $r.tag_name
$r = Select-AnvilRelease -Releases @($oldList)
Assert-That 'default when the newest is an rc: v0.2.0-rc.1' ($r.tag_name -eq 'v0.2.0-rc.1') $r.tag_name
$r = Select-AnvilRelease -Releases @($oldList) -Stable
Assert-That '-Stable skips the rc: v0.1.6' ($r.tag_name -eq 'v0.1.6') $r.tag_name
$r = Select-AnvilRelease -Releases @($list) -Tag 'v0.2.0-rc.1'
Assert-That 'explicit tag from the list: v0.2.0-rc.1' ($r.tag_name -eq 'v0.2.0-rc.1') $r.tag_name
$r = Select-AnvilRelease -Releases @($v016) -Tag 'v0.1.6'
Assert-That 'explicit tag from releases/tags: v0.1.6' ($r.tag_name -eq 'v0.1.6')
Assert-That 'explicit draft tag (list) is never chosen' ($null -eq (Select-AnvilRelease -Releases @($list) -Tag 'v0.3.0'))
Assert-That 'explicit draft tag (tags/ file) is never chosen' ($null -eq (Select-AnvilRelease -Releases @($draft) -Tag 'v0.3.0'))
Assert-That 'unknown tag: none' ($null -eq (Select-AnvilRelease -Releases @($list) -Tag 'v9.9.9'))

$cases = @(
    @('0.2.0-rc.1', '0.2.0', -1),
    @('0.1.6', '0.2.0-rc.1', -1),
    @('0.2.0', '0.2.0', 0),
    @('0.2.0-rc.1', '0.2.0-rc.1', 0),
    @('0.2.0', '0.2.0-rc.1', 1),
    @('0.2.0-rc.2', '0.2.0-rc.10', -1),
    @('0.10.0', '0.9.0', 1),
    @('v0.2.0', '0.2.0', 0),
    @('1.0.0', '0.99.99', 1),
    @('garbage', '0.2.0', -1),
    @('', '0.2.0', -1)
)
foreach ($c in $cases) {
    $got = Compare-AnvilVersion $c[0] $c[1]
    Assert-That "Compare-AnvilVersion '$($c[0])' '$($c[1])' = $($c[2])" ($got -eq $c[2]) "got $got"
}
$threw = $false
try { Compare-AnvilVersion '0.2.0' 'nope' | Out-Null } catch { $threw = $true }
Assert-That 'Compare-AnvilVersion throws on a target that is not a version' $threw

Assert-That 'asset name for v0.2.0' ((Get-AnvilAssetName 'v0.2.0') -eq 'anvil-0.2.0-windows-x64-setup.exe')
$asset = Find-AnvilAsset $v020 (Get-AnvilAssetName 'v0.2.0')
Assert-That 'v0.2.0: setup exe found' ($null -ne $asset)
if ($null -ne $asset) {
    $served = Join-Path $FakeDir 'download/v0.2.0/anvil-0.2.0-windows-x64-setup.exe'
    $hash = (Get-FileHash -LiteralPath $served -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-That 'v0.2.0: expected sha256 is the served file''s' ((Get-ExpectedSha256 $asset) -eq $hash)
}
$rcRelease = Select-AnvilRelease -Releases @($list) -Tag 'v0.2.0-rc.1'
Assert-That 'v0.2.0-rc.1: setup exe found' ($null -ne (Find-AnvilAsset $rcRelease (Get-AnvilAssetName 'v0.2.0-rc.1')))
Assert-That 'v0.1.6: no setup exe (electron-builder names)' ($null -eq (Find-AnvilAsset $v016 (Get-AnvilAssetName 'v0.1.6')))
Assert-That 'asset names match case-sensitively' ($null -eq (Find-AnvilAsset $v020 'ANVIL-0.2.0-windows-x64-setup.exe'))
Assert-That 'a missing digest gives an empty string' ((Get-ExpectedSha256 ([pscustomobject]@{ name = 'x'; digest = $null })) -eq '')
Assert-That 'an asset without a digest field gives an empty string' ((Get-ExpectedSha256 ([pscustomobject]@{ name = 'x' })) -eq '')
Assert-That 'another algorithm gives $null' ($null -eq (Get-ExpectedSha256 ([pscustomobject]@{ digest = 'sha512:abcd' })))

$a = Get-InstallerArgumentString -Scope 'AllUsers' -InstallDir 'C:\Apps\Anvil\' -LogPath 'C:\Temp\s.log'
Assert-That 'Setup args: silent, no reboot, close without restart' ($a -like '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /CLOSEAPPLICATIONS /NORESTARTAPPLICATIONS*') $a
Assert-That 'Setup args: /ALLUSERS and a quoted /DIR without a trailing backslash' ($a -match '/ALLUSERS' -and $a -match '/DIR="C:\\Apps\\Anvil"') $a
Assert-That 'Setup args: /LOG' ($a -match '/LOG="C:\\Temp\\s.log"') $a
$a = Get-InstallerArgumentString -Scope 'CurrentUser'
Assert-That 'Setup args: per user by default, no /DIR' ($a -match '/CURRENTUSER' -and $a -notmatch '/DIR' -and $a -notmatch 'FORCECLOSE') $a
Assert-That 'exit code 5 explains a file in use' ((Get-SetupExitMeaning 5) -match 'still open')

# --- PSScriptAnalyzer ---
if ($Analyze) {
    try {
        if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
            Set-PSRepository PSGallery -InstallationPolicy Trusted
            Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
        }
        Import-Module PSScriptAnalyzer
        foreach ($path in $scriptPath, $PSCommandPath) {
            $findings = @(Invoke-ScriptAnalyzer -Path $path)
            Write-Host "PSScriptAnalyzer $(Split-Path -Leaf $path): $($findings.Count) finding(s)"
            foreach ($f in $findings) { Write-Host "  $($f.Severity) $($f.RuleName) line $($f.Line): $($f.Message)" }
        }
        # Windows PowerShell 5.1 on Windows 10 / Server 2019, one of the
        # profiles PSScriptAnalyzer ships. PSUseCompatibleCommands flags
        # 7-only cmdlets and parameters (it reports Get-Uptime and
        # -SkipHttpErrorCheck against it); the older PSUseCompatibleCmdlets
        # did not, so it is not used.
        $desktop51 = 'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'
        $compat = @(Invoke-ScriptAnalyzer -Path $scriptPath -Settings @{
                Rules        = @{
                    PSUseCompatibleSyntax   = @{ Enable = $true; TargetVersions = @('5.1', '7.0') }
                    PSUseCompatibleCommands = @{ Enable = $true; TargetProfiles = @($desktop51) }
                    PSUseCompatibleTypes    = @{ Enable = $true; TargetProfiles = @($desktop51) }
                }
                IncludeRules = @('PSUseCompatibleSyntax', 'PSUseCompatibleCommands', 'PSUseCompatibleTypes')
            })
        Write-Host "PSScriptAnalyzer 5.1 compatibility rules: $($compat.Count) finding(s)"
        foreach ($f in $compat) { Write-Host "  $($f.RuleName) line $($f.Line): $($f.Message)" }
        Assert-That 'PSUseCompatibleSyntax/Commands/Types for 5.1: no findings' ($compat.Count -eq 0)
    } catch {
        Write-Host "PSScriptAnalyzer not run: $($_.Exception.Message)"
    }
}

Write-Host ''
if ($script:failures -eq 0) {
    Write-Host 'ALL PASSED (pwsh)'
    exit 0
}
Write-Host "$($script:failures) CHECK(S) FAILED (pwsh)"
exit 1
