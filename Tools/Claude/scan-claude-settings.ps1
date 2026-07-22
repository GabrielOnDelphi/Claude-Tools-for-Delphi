# =====================================================================================
# scan-claude-settings.ps1  --  weekly tripwire for Claude Code config drift
# -------------------------------------------------------------------------------------
# Detects NEW / CHANGED / REMOVED Claude config files (settings.json,
# settings.local.json, .mcp.json). On drift it BEEPS, logs the exact files, and tells
# you to run /light-sec-SettingsAudit for the full DANGEROUS/SUSPICIOUS/SAFE judgment.
#
# This is a cheap CHANGE-DETECTOR, not a scanner: no tokens, no LLM, no alarm fatigue.
# It ignores your known-good current config (the baseline) and alerts only on drift --
# which is exactly the moment a cloned/3rd-party repo plants new config.
#
# CALLER: the alternative action for the weekly Windows Scheduled Task
#         "ClaudeSettingsWeeklyAudit" (default action = the token-spending
#         run-settings-audit-headless.ps1; swap to this for the no-token path).
#         Safe to run by hand anytime. First run just records the baseline (no alarm).
#
# Companion deep-audit (full judgment): /light-sec-SettingsAudit  (skill + agent).
# Created 2026-07-02. Moved into Tools\Claude\ 2026-07-20.
# =====================================================================================

$ErrorActionPreference = 'SilentlyContinue'

# Roots to recurse. C:\Users\trei\.claude holds user settings + plugin/marketplace
# .mcp.json; the rest are the project trees. Full C:\Users\trei is deliberately NOT
# recursed (AppData bloat) -- all real Claude config lives in these roots.
$RecurseRoots = @(
  'C:\AI',
  'C:\Projects',
  'C:\Delphi',
  'C:\Users\trei\.claude',
  'C:\Program Files\ClaudeCode'
)
$BaselinePath = 'C:\AI\Claude Code\Temp\claude-settings-baseline.json'
$LogPath      = 'C:\AI\Claude Code\Temp\claude-settings-audit.log'
$BeepWav      = 'C:\AI\Claude Code\Tools\Claude\task_done_beep.wav'

function Get-ConfigFiles {
  $files = New-Object System.Collections.Generic.List[string]
  foreach ($root in $RecurseRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    # settings.json / settings.local.json -- only inside a .claude folder, or the managed dir
    Get-ChildItem -Path $root -Recurse -Force -File -Include 'settings.json','settings.local.json' -ErrorAction SilentlyContinue |
      Where-Object { $_.DirectoryName -match '\\\.claude$' -or $_.FullName -like 'C:\Program Files\ClaudeCode\*' } |
      ForEach-Object { $files.Add($_.FullName) }
    # any .mcp.json
    Get-ChildItem -Path $root -Recurse -Force -File -Filter '.mcp.json' -ErrorAction SilentlyContinue |
      ForEach-Object { $files.Add($_.FullName) }
  }
  $files | Sort-Object -Unique
}

# --- current snapshot: path -> SHA256 -------------------------------------------------
$current = @{}
foreach ($f in Get-ConfigFiles) {
  try { $current[$f] = (Get-FileHash -LiteralPath $f -Algorithm SHA256 -ErrorAction Stop).Hash } catch {}
}

# --- load baseline --------------------------------------------------------------------
$firstRun = -not (Test-Path -LiteralPath $BaselinePath)
$baseline = @{}
if (-not $firstRun) {
  try {
    $obj = Get-Content -Raw -LiteralPath $BaselinePath | ConvertFrom-Json
    foreach ($p in $obj.PSObject.Properties) { $baseline[$p.Name] = $p.Value }
  } catch { $firstRun = $true }  # unreadable baseline -> treat as first run
}

# --- diff -----------------------------------------------------------------------------
$added = @(); $changed = @(); $removed = @()
foreach ($k in $current.Keys) {
  if (-not $baseline.ContainsKey($k)) { $added += $k }
  elseif ($baseline[$k] -ne $current[$k]) { $changed += $k }
}
foreach ($k in $baseline.Keys) {
  if (-not $current.ContainsKey($k)) { $removed += $k }
}

# --- report ---------------------------------------------------------------------------
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
if ($firstRun) {
  $msg = "[$stamp] Baseline created: $($current.Count) Claude config files tracked. No alarm on first run."
  Add-Content -LiteralPath $LogPath -Value $msg
  Write-Output $msg
}
elseif ($added.Count -or $changed.Count -or $removed.Count) {
  $lines = @("[$stamp] DRIFT DETECTED in Claude config -- run /light-sec-SettingsAudit for a full review.")
  foreach ($a in $added)   { $lines += "  NEW:     $a" }
  foreach ($c in $changed) { $lines += "  CHANGED: $c" }
  foreach ($r in $removed) { $lines += "  REMOVED: $r" }
  foreach ($ln in $lines) { Add-Content -LiteralPath $LogPath -Value $ln; Write-Output $ln }
  try { (New-Object Media.SoundPlayer $BeepWav).PlaySync() } catch { [console]::beep(880,400) }
}
else {
  $msg = "[$stamp] OK -- no change in $($current.Count) Claude config files."
  Add-Content -LiteralPath $LogPath -Value $msg
  Write-Output $msg
}

# --- persist updated baseline (so each drift alerts once) -----------------------------
ConvertTo-Json -InputObject $current -Depth 3 | Set-Content -LiteralPath $BaselinePath -Encoding UTF8
