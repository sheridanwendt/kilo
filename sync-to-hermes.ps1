<#
.SYNOPSIS
  Syncs this repo's authored Hermes content (skills/, and memories/, cron/,
  hooks/ once populated) onto an *existing* Hermes agent installation on
  Windows.

.DESCRIPTION
  For someone who already has a working Hermes agent and just wants this
  repo's content applied or refreshed, without a full install (no OS
  packages, no Ollama, no config.yaml changes - this repo's install.sh
  doesn't run natively on Windows at all; see ADR-0007/ADR-00xx).

    git clone https://github.com/sheridanwendt/kilo.git
    cd kilo
    .\sync-to-hermes.ps1

  Linux/macOS/WSL2 equivalent: sync-to-hermes.sh (bash) - same content,
  same behavior, native tooling per OS.

  Idempotent and safe to re-run: each synced item is fully replaced from
  this repo's copy every time.

.PARAMETER HermesDir
  Override the detected Hermes agent directory.
  Default: $env:HPA_HERMES_DIR if set, else "$env:LOCALAPPDATA\hermes".
  See docs/open-questions.md #11 - this, and the memories/cron/hooks
  locations below it, are best-effort assumptions about Hermes's
  directory layout, not confirmed against every possible Hermes version.

.PARAMETER Yes
  Skip the confirmation prompt.

.PARAMETER DryRun
  Show what would be copied without copying anything.

.EXAMPLE
  .\sync-to-hermes.ps1
.EXAMPLE
  .\sync-to-hermes.ps1 -HermesDir "D:\hermes" -Yes
.EXAMPLE
  .\sync-to-hermes.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$HermesDir = $(if ($env:HPA_HERMES_DIR) { $env:HPA_HERMES_DIR } else { Join-Path $env:LOCALAPPDATA "hermes" }),
    [switch]$Yes,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OverlayDir = Join-Path $ScriptDir "overlay"
$Categories = @("skills", "memories", "cron", "hooks")

if (-not (Test-Path -LiteralPath $HermesDir -PathType Container)) {
    Write-Error (
        "No Hermes agent directory found at: $HermesDir`n" +
        "  - If Hermes is installed somewhere else, pass -HermesDir <path> or set HPA_HERMES_DIR.`n" +
        "  - If Hermes isn't installed yet, this script only syncs content onto an *existing* agent."
    )
    exit 1
}

Write-Host "==> Hermes agent directory: $HermesDir"

$FoundCategories = $Categories | Where-Object {
    Test-Path -LiteralPath (Join-Path $OverlayDir $_) -PathType Container
}

if (-not $FoundCategories) {
    Write-Host "  - Nothing to sync: no overlay/{$($Categories -join ',')} directories have content in this repo yet."
    exit 0
}

Write-Host "  - Will sync: $($FoundCategories -join ', ')"
if ($DryRun) {
    Write-Host "  - (-DryRun: showing what would happen, nothing will be changed)"
}

if (-not $Yes -and -not $DryRun) {
    $reply = Read-Host "Overwrite matching content under $HermesDir? [y/N]"
    if ($reply -notmatch '^[yY]') {
        Write-Host "Aborted."
        exit 1
    }
}

# skills/ gets special handling (mirrors overlay/install/05-* logic this
# replaces on the Linux side): only directories containing a SKILL.md are
# installed, under a skills\custom\ subfolder, so a stray README.md
# alongside the skill directories in overlay\skills\custom\ doesn't get
# copied in too.
function Sync-Skills {
    $src = Join-Path $OverlayDir "skills\custom"
    $target = Join-Path $HermesDir "skills\custom"
    if (-not (Test-Path -LiteralPath $src -PathType Container)) { return }

    Get-ChildItem -LiteralPath $src -Directory | ForEach-Object {
        $name = $_.Name
        $skillMd = Join-Path $_.FullName "SKILL.md"
        if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) {
            Write-Host "    - skills: skipping $name (no SKILL.md)"
            return
        }
        $destPath = Join-Path $target $name
        if ($DryRun) {
            Write-Host "    - skills: would install $name -> $destPath"
        } else {
            New-Item -ItemType Directory -Force -Path $target | Out-Null
            if (Test-Path -LiteralPath $destPath) {
                Remove-Item -LiteralPath $destPath -Recurse -Force
            }
            Copy-Item -LiteralPath $_.FullName -Destination $destPath -Recurse -Force
            Write-Host "    - skills: installed $name"
        }
    }
}

# memories\, cron\, hooks\: straight mirror, whole directory tree,
# whenever this repo actually has content for them.
function Sync-DirCategory {
    param([string]$Category)
    $src = Join-Path $OverlayDir $Category
    $target = Join-Path $HermesDir $Category
    if (-not (Test-Path -LiteralPath $src -PathType Container)) { return }

    if ($DryRun) {
        Write-Host "    - ${Category}: would mirror $src -> $target"
    } else {
        New-Item -ItemType Directory -Force -Path $target | Out-Null
        Copy-Item -Path (Join-Path $src "*") -Destination $target -Recurse -Force
        Write-Host "    - ${Category}: synced"
    }
}

foreach ($category in $FoundCategories) {
    Write-Host "  - Category: $category"
    if ($category -eq "skills") {
        Sync-Skills
    } else {
        Sync-DirCategory -Category $category
    }
}

if ($DryRun) {
    Write-Host "==> Dry run complete, nothing was changed."
} else {
    Write-Host "==> Sync complete."
}
