# Brings the terminal window hosting Claude Code to the foreground.
# CALLER: the Stop hook in ~\.claude\settings.json (runs right after the task-done beep).
#         If you rename/move this script, update that hook's -File path.
#
# Why the parent-chain walk: under Windows Terminal, GetConsoleWindow() returns a
# HIDDEN pseudo-console handle, not the visible window. So we walk up the process
# tree from this PowerShell to the first ancestor that owns a real MainWindowHandle
# (conhost / WindowsTerminal / the host app), then restore + foreground it.
# Falls back to FindWindow on the Windows Terminal class, then FlashWindow.

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern IntPtr FindWindow(string c, string w);
  [DllImport("user32.dll")] public static extern bool FlashWindow(IntPtr h, bool b);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
}
"@

$SW_RESTORE = 9

function Bring([IntPtr]$h) {
  if ($h -eq [IntPtr]::Zero) { return $false }
  [Win]::ShowWindow($h, $SW_RESTORE) | Out-Null
  [Win]::BringWindowToTop($h) | Out-Null
  $ok = [Win]::SetForegroundWindow($h)
  if (-not $ok) { [Win]::FlashWindow($h, $true) | Out-Null }  # focus-stealing blocked -> flash taskbar
  return $true
}

# Walk up the parent-process chain looking for a real window handle.
$hwnd = [IntPtr]::Zero
try {
  $pid = $PID
  for ($i = 0; $i -lt 12 -and $pid -ne 0; $i++) {
    $p = Get-CimInstance Win32_Process -Filter "ProcessId=$pid" -ErrorAction Stop
    if (-not $p) { break }
    try {
      $proc = Get-Process -Id $pid -ErrorAction Stop
      if ($proc.MainWindowHandle -ne [IntPtr]::Zero) { $hwnd = $proc.MainWindowHandle; break }
    } catch {}
    $pid = [int]$p.ParentProcessId
  }
} catch {}

# Fallback: the Windows Terminal top-level window class.
if ($hwnd -eq [IntPtr]::Zero) {
  $hwnd = [Win]::FindWindow("CASCADIA_HOSTING_WINDOW_CLASS", $null)
}

Bring $hwnd | Out-Null
