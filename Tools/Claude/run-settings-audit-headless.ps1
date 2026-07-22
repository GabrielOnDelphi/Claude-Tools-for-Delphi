# =====================================================================================
# run-settings-audit-headless.ps1  --  weekly FULL Claude config audit (headless, Sonnet)
# -------------------------------------------------------------------------------------
# Runs the /light-sec-SettingsAudit skill in headless print mode on Sonnet, saves the
# full DANGEROUS/SUSPICIOUS/SAFE report to Temp\settings-audit-<stamp>.md, logs a line,
# and BEEPS only when the verdict reports 1+ DANGEROUS findings (your broad-allow config
# is "suspicious" by rubric every week -- beeping on that would be pure noise).
#
# CALLER: Windows Scheduled Task "ClaudeSettingsWeeklyAudit" (Sundays 12:00) runs this file.
#         If you rename/move it, update that task's action (Set-ScheduledTask -Action ...).
# Costs tokens (one Sonnet audit/week). The cheap no-token alternative is the
# change-detector Tools\Claude\scan-claude-settings.ps1 (kept on disk; swap the task action back
# to it if you want to stop spending tokens).
# Created 2026-07-02. Moved into Tools\Claude\ 2026-07-20.
# =====================================================================================

$ErrorActionPreference = 'SilentlyContinue'

$claude    = 'C:\Users\trei\.local\bin\claude.exe'
$projectDir= 'C:\AI\Claude Code'          # trusted folder to run the audit from
$reportDir = 'C:\AI\Claude Code\Temp'
$log       = Join-Path $reportDir 'claude-settings-audit.log'
$beep      = 'C:\AI\Claude Code\Tools\Claude\task_done_beep.wav'
$prompt    = '/light-sec-SettingsAudit'
$stamp     = Get-Date -Format 'yyyy-MM-dd_HHmm'
$report    = Join-Path $reportDir ("settings-audit-$stamp.md")

Set-Location -LiteralPath $projectDir

# Feed empty stdin so headless claude doesn't stall 3s waiting for pipe input.
$out = '' | & $claude --model claude-sonnet-5 -p $prompt 2>&1 | Out-String
Set-Content -LiteralPath $report -Value $out -Encoding UTF8

$now = Get-Date -Format 'yyyy-MM-dd HH:mm'
# DANGEROUS if the verdict names a non-zero dangerous count (e.g. "2 dangerous / 5 suspicious").
$hasDanger = ($out -match '(?im)[1-9]\d*\s*dangerous')
if ($hasDanger) {
  Add-Content -LiteralPath $log -Value "[$now] FULL AUDIT (Sonnet): DANGEROUS findings -> $report"
  try { (New-Object Media.SoundPlayer $beep).PlaySync() } catch { [console]::beep(880,400) }
}
elseif ($out -match '(?im)\bCLEAN\b' -or $out -match '(?im)\b0\s*dangerous') {
  Add-Content -LiteralPath $log -Value "[$now] FULL AUDIT (Sonnet): clean -> $report"
}
else {
  # Unexpected/empty output (e.g. skill didn't run) -- log it so a silent failure is visible.
  Add-Content -LiteralPath $log -Value "[$now] FULL AUDIT (Sonnet): UNCLEAR result, review -> $report"
  try { (New-Object Media.SoundPlayer $beep).PlaySync() } catch { [console]::beep(880,400) }
}
