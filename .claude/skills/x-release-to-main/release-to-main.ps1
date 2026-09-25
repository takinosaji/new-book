#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][Alias('m')][string]$Message,
    [string[]]$Exclude = @(),
    [switch]$DryRun,
    [switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Remote = if ($env:RELEASE_REMOTE) { $env:RELEASE_REMOTE } else { 'origin' }
$MainBranch = if ($env:RELEASE_MAIN_BRANCH) { $env:RELEASE_MAIN_BRANCH } else { 'main' }
$DevBranch = if ($env:RELEASE_DEV_BRANCH) { $env:RELEASE_DEV_BRANCH } else { 'development' }
$SnapshotMessage = if ($env:RELEASE_SNAPSHOT_MESSAGE) { $env:RELEASE_SNAPSHOT_MESSAGE } else { 'Initial commit' }

function Stop-WithError([string]$Text) {
    [Console]::Error.WriteLine("ERROR: $Text")
    exit 1
}

function Invoke-GitCapture([string[]]$GitArgs) {
    $output = & git @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "git $($GitArgs -join ' ') failed:`n$($output | Out-String)"
    }
    return ($output | Out-String).TrimEnd()
}

function Invoke-GitCommand([string[]]$GitArgs) {
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "git $($GitArgs -join ' ') failed"
    }
}

function Test-GitSucceeds([string[]]$GitArgs) {
    & git @GitArgs *> $null
    return ($LASTEXITCODE -eq 0)
}

function Measure-Lines([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return 0 }
    return ($Text -split "`r?`n" | Where-Object { $_ -ne '' }).Count
}

if ([string]::IsNullOrWhiteSpace($Message)) {
    Stop-WithError 'a non-empty commit message is required (-Message)'
}

if (-not (Test-GitSucceeds @('rev-parse', '--git-dir'))) {
    Stop-WithError 'not inside a git repository'
}
Set-Location (Invoke-GitCapture @('rev-parse', '--show-toplevel'))

$pathspec = @('--', '.')
foreach ($ex in $Exclude) { $pathspec += ":(exclude)$ex" }

$currentBranch = Invoke-GitCapture @('rev-parse', '--abbrev-ref', 'HEAD')
if ($currentBranch -ne $MainBranch -and $currentBranch -ne $DevBranch) {
    Stop-WithError "HEAD is on '$currentBranch'; check out '$MainBranch' or '$DevBranch' first"
}

if ((Invoke-GitCapture @('ls-files', '--unmerged')) -ne '') {
    Stop-WithError 'unresolved merge conflicts in the index'
}
foreach ($state in @('rebase-merge', 'rebase-apply')) {
    if (Test-Path (Invoke-GitCapture @('rev-parse', '--git-path', $state))) {
        Stop-WithError 'a rebase is in progress'
    }
}

foreach ($branch in @($MainBranch, $DevBranch)) {
    if (-not (Test-GitSucceeds @('show-ref', '--verify', '--quiet', "refs/heads/$branch"))) {
        Stop-WithError "local branch '$branch' not found"
    }
}

Write-Host "Fetching $Remote ..."
Invoke-GitCommand @('fetch', '--quiet', $Remote, $MainBranch, $DevBranch)

$mainTree = Invoke-GitCapture @('rev-parse', "$MainBranch^{tree}")
$devTree = Invoke-GitCapture @('rev-parse', "$DevBranch^{tree}")
if ($mainTree -ne $devTree) {
    Stop-WithError @"
'$MainBranch' and '$DevBranch' have different trees.
  $MainBranch tree: $mainTree
  $DevBranch tree: $devTree
This script assumes '$MainBranch' is a snapshot of '$DevBranch'. Reconcile
them by hand before releasing, or work committed only on one branch will be
silently discarded.
"@
}

$localMain = Invoke-GitCapture @('rev-parse', $MainBranch)
$remoteMain = Invoke-GitCapture @('rev-parse', "$Remote/$MainBranch")
if ($localMain -ne $remoteMain) {
    Stop-WithError "local '$MainBranch' ($localMain) differs from '$Remote/$MainBranch' ($remoteMain); fetch and reconcile first"
}

if (-not (Test-GitSucceeds @('merge-base', '--is-ancestor', "$Remote/$DevBranch", $DevBranch))) {
    Stop-WithError "local '$DevBranch' is behind '$Remote/$DevBranch'; pull or rebase first"
}

$toCommit = Invoke-GitCapture (@('status', '--porcelain') + $pathspec)
if ([string]::IsNullOrWhiteSpace($toCommit)) {
    Stop-WithError 'nothing to release: no changes outside the excluded paths'
}

Write-Host ''
Write-Host '================ RELEASE PLAN ================'
Write-Host "repository:  $(Get-Location)"
Write-Host "remote:      $Remote"
Write-Host "message:     $Message"
Write-Host ''
Write-Host "WILL BE COMMITTED to '$DevBranch':"
$toCommit -split "`r?`n" | ForEach-Object { Write-Host "    $_" }
if ($Exclude.Count -gt 0) {
    Write-Host ''
    Write-Host 'EXCLUDED, left in the working tree:'
    foreach ($ex in $Exclude) {
        $excludedStatus = Invoke-GitCapture @('status', '--porcelain', '--', $ex)
        if ([string]::IsNullOrWhiteSpace($excludedStatus)) {
            Write-Host "    ($ex matches nothing)"
        }
        else {
            $excludedStatus -split "`r?`n" | ForEach-Object { Write-Host "    $_" }
        }
    }
}
Write-Host ''
Write-Host "Then '$MainBranch' becomes ONE parentless commit `"$SnapshotMessage`""
Write-Host "and is force-pushed, replacing $remoteMain"
Write-Host ''
Write-Host 'Recovery if this goes wrong:'
Write-Host "    git push --force $Remote ${remoteMain}:$MainBranch"
Write-Host '=============================================='
Write-Host ''

if ($DryRun) {
    Write-Host '-DryRun: all preconditions passed, nothing was changed.'
    exit 0
}

Write-Host 'Everything under WILL BE COMMITTED goes in, untracked files included.'
if ($Yes) {
    Write-Host '(-Yes given, skipping confirmation)'
}
else {
    $reply = Read-Host "Type 'release' to proceed"
    if ($reply -ne 'release') { Stop-WithError 'aborted by user' }
}

Write-Host "==> switching to $DevBranch"
Invoke-GitCommand @('switch', $DevBranch)

Write-Host "==> committing to $DevBranch"
Invoke-GitCommand (@('add', '-A') + $pathspec)
Invoke-GitCommand @('commit', '-m', $Message)
$devCommit = Invoke-GitCapture @('rev-parse', 'HEAD')

Write-Host "==> pushing $DevBranch"
Invoke-GitCommand @('push', $Remote, $DevBranch)

Write-Host "==> rebuilding $MainBranch as a single snapshot commit"
$snapshot = Invoke-GitCapture @('commit-tree', "$DevBranch^{tree}", '-m', $SnapshotMessage)
Invoke-GitCommand @('branch', '-f', $MainBranch, $snapshot)

Write-Host "==> force-pushing $MainBranch"
Invoke-GitCommand @('push', "--force-with-lease=${MainBranch}:$remoteMain", $Remote, $MainBranch)

Write-Host "==> returning to $MainBranch"
Invoke-GitCommand @('switch', $MainBranch)

Write-Host '==> verifying postconditions'
$failures = 0
function Assert-Equal([string]$Label, [string]$Actual, [string]$Expected) {
    if ($Actual -eq $Expected) {
        Write-Host "    OK   $Label"
    }
    else {
        Write-Host "    FAIL $Label (expected $Expected, got $Actual)"
        $script:failures++
    }
}
Assert-Equal "$MainBranch has exactly 1 commit" (Invoke-GitCapture @('rev-list', '--count', $MainBranch)) '1'
Assert-Equal "$MainBranch commit is parentless" ((Invoke-GitCapture @('rev-list', '--parents', '-n1', $MainBranch)).Split(' ').Count) '1'
Assert-Equal "$MainBranch tree == $DevBranch tree" (Invoke-GitCapture @('rev-parse', "$MainBranch^{tree}")) (Invoke-GitCapture @('rev-parse', "$DevBranch^{tree}"))
Assert-Equal "$Remote/$MainBranch updated" (Invoke-GitCapture @('rev-parse', "$Remote/$MainBranch")) $snapshot
Assert-Equal "$Remote/$DevBranch updated" (Invoke-GitCapture @('rev-parse', "$Remote/$DevBranch")) $devCommit
Assert-Equal 'nothing uncommitted outside excludes' (Measure-Lines (Invoke-GitCapture (@('status', '--porcelain') + $pathspec))) '0'

Write-Host ''
if ($failures -gt 0) {
    Stop-WithError "$failures postcondition(s) failed. Recover with: git push --force $Remote ${remoteMain}:$MainBranch"
}
Write-Host 'Released.'
Write-Host "  ${DevBranch}: $devCommit  $Message"
Write-Host "  ${MainBranch}: $snapshot  $SnapshotMessage"
Write-Host "  previous $MainBranch was $remoteMain"
if ($Exclude.Count -gt 0) {
    Write-Host "  excluded from the commit: $($Exclude -join ', ')"
}
