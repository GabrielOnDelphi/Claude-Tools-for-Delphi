<#
  Drive-DelphiDialogs.ps1
  ------------------------
  Read and dismiss native Windows message boxes (#32770) of a target process, using raw Win32.
  Purpose: let Claude drive a Delphi GUI app that has NO Autopilot bridge compiled in
  (Autopilot's MCP can only attach to apps that embed its pipe server). Every VCL
  Assert / unhandled-exception / MessageDlg shows as a #32770 dialog, so this captures
  their exact text and can click OK/Yes/etc. — turning a blocking modal into readable data.

  Typical use (launch + watch the whole startup, auto-click OK, print every dialog seen):
    powershell -File "C:\AI\Claude Code\Tools\Drive-DelphiDialogs.ps1" -Exe "C:\...\MyProduct.exe" -Launch -WatchSeconds 25 -ClickButton OK

  Attach to an already-running app and just READ (do not click):
    powershell -File "...\Drive-DelphiDialogs.ps1" -ProcName MyProduct -WatchSeconds 10 -ClickButton ""

  Output: one line per dialog ->  [hh:mm:ss] TITLE :: message text :: clicked=<button|NONE>
  Exit code 0 always. "CLEAN" is printed if no dialog appeared during the watch window.
#>
param(
  [string]$Exe = "",
  [string]$ProcName = "",
  [int]$ProcId = 0,
  [int]$WatchSeconds = 20,
  [string]$ClickButton = "OK",   # caption to auto-click (& stripped, case-insensitive, substring ok). "" = read only, never click.
  [switch]$Launch
)

Add-Type @"
using System;using System.Text;using System.Runtime.InteropServices;
public class Dlg{
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
 [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr l);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowTextLength(IntPtr h);
 [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
 public delegate bool EnumProc(IntPtr h, IntPtr l);
}
"@

function Get-Pid {
  if ($ProcId -ne 0) { return $ProcId }
  if ($ProcName -ne "") { $p = Get-Process $ProcName -ErrorAction SilentlyContinue | Select-Object -First 1; if ($p) { return $p.Id } }
  if ($Exe -ne "")     { $n = [IO.Path]::GetFileNameWithoutExtension($Exe); $p = Get-Process $n -ErrorAction SilentlyContinue | Select-Object -First 1; if ($p) { return $p.Id } }
  return 0
}

if ($Launch -and $Exe -ne "") {
  Start-Process -FilePath $Exe -WorkingDirectory ([IO.Path]::GetDirectoryName($Exe)) | Out-Null
  Start-Sleep -Milliseconds 300
}

$targetPid = Get-Pid
if ($targetPid -eq 0) { "ERROR: target process not found (Exe/ProcName/ProcId gave nothing)."; exit 0 }
"WATCHING pid=$targetPid for ${WatchSeconds}s (click='$ClickButton')"

$seen = @{}
$any = $false
$deadline = (Get-Date).AddSeconds($WatchSeconds)

while ((Get-Date) -lt $deadline) {
  # collect visible #32770 dialogs of the target pid
  $dialogs = New-Object System.Collections.ArrayList
  $cb = [Dlg+EnumProc]{ param($h,$l)
    $p=0; [Dlg]::GetWindowThreadProcessId($h,[ref]$p) | Out-Null
    if ($p -eq $targetPid -and [Dlg]::IsWindowVisible($h)) {
      $c = New-Object Text.StringBuilder 64; [Dlg]::GetClassName($h,$c,64) | Out-Null
      if ($c.ToString() -eq '#32770') { [void]$dialogs.Add($h) }
    }
    return $true }
  [Dlg]::EnumWindows($cb,[IntPtr]::Zero) | Out-Null

  foreach ($h in $dialogs) {
    $key = [int64]$h
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $any = $true

    # dialog caption
    $len = [Dlg]::GetWindowTextLength($h); $t = New-Object Text.StringBuilder ($len+2); [Dlg]::GetWindowText($h,$t,$len+2) | Out-Null
    $title = $t.ToString()

    # walk children: Static -> message text, Button -> candidate to click
    $texts   = New-Object System.Collections.ArrayList
    $buttons = New-Object System.Collections.ArrayList
    $ccb = [Dlg+EnumProc]{ param($ch,$l)
      $cc = New-Object Text.StringBuilder 64; [Dlg]::GetClassName($ch,$cc,64) | Out-Null
      $cls = $cc.ToString()
      $cl = [Dlg]::GetWindowTextLength($ch); $cs = New-Object Text.StringBuilder ($cl+2); [Dlg]::GetWindowText($ch,$cs,$cl+2) | Out-Null
      $txt = $cs.ToString()
      if ($cls -eq 'Static' -and $txt.Trim().Length -gt 0) { [void]$script:texts.Add($txt) }
      if ($cls -eq 'Button') { [void]$script:buttons.Add([pscustomobject]@{h=$ch; text=$txt}) }
      return $true }
    [Dlg]::EnumChildWindows($h, $ccb, [IntPtr]::Zero) | Out-Null

    $msg = ($texts -join ' | ') -replace '\s+',' '
    $clicked = 'NONE'
    if ($ClickButton -ne '') {
      $want = $ClickButton.Replace('&','')
      $btn = $buttons | Where-Object { $_.text.Replace('&','') -ieq $want } | Select-Object -First 1
      if (-not $btn) { $btn = $buttons | Where-Object { $_.text.Replace('&','') -ilike "*$want*" } | Select-Object -First 1 }
      if (-not $btn -and $buttons.Count -gt 0) { $btn = $buttons[0] }  # fallback: first button (usually OK/default)
      if ($btn) {
        # BM_CLICK = 0x00F5
        [Dlg]::SendMessage($btn.h, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        $clicked = $btn.text.Replace('&','')
      }
    }
    "[{0:HH:mm:ss}] {1} :: {2} :: clicked={3}" -f (Get-Date), $title, $msg, $clicked
  }
  Start-Sleep -Milliseconds 200
}

if (-not $any) { "CLEAN: no #32770 dialog appeared during the watch window." }
$alive = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
if ($alive) { "PROCESS STILL ALIVE (pid=$targetPid)." } else { "PROCESS EXITED during/after watch." }
exit 0
