# Forces this PC into SLEEP (standby S3 / Modern-Standby S0), bypassing wake-locks.
# CALLER: Claude Code on user command ("sleep the PC" / "sleep now" / "/sleep") via Tools\Claude\Sleep.cmd.
#         Also runnable by hand:  ! Tools\Claude\Sleep.cmd     or    powershell -File Sleep-PC.ps1
#         If you rename/move this script, update Sleep.cmd and the CLAUDE.md pointer.
#
# Primitive: the SAME Win32 call the user's LightSleep tool uses and has tested on Win 7/10/11 -
#   SetSuspendState(bHibernate=FALSE, bForce, DisableWakeEvent)   (powrprof.dll)
#   -> here via its documented .NET wrapper  Application.SetSuspendState(PowerState.Suspend, force, disableWakeEvent).
#   PowerState.Suspend = standby/sleep (value 0), NOT hibernate (value 1).
#   Verified against learn.microsoft.com - see Sleep-README.md.
#
# Why NOT the popular  rundll32 powrprof.dll,SetSuspendState 0,1,0  : that one-liner IGNORES its string
#   args and HIBERNATES whenever hibernation is enabled. This call passes PowerState.Suspend explicitly,
#   so it always SLEEPS regardless of the machine's hibernation setting.
#
# On Vista+ SetSuspendState does not go through the vetoable PBT_APMQUERYSUSPEND broadcast, so other
# apps' ES_SYSTEM_REQUIRED wake-locks (Firefox, Claude desktop, Steam, ...) cannot keep the PC awake.

param(
  [int]    $DelaySeconds = 5,      # grace period so the caller's final output + done-beep flush before the screen goes off
  [switch] $Hibernate,            # sleep by default; pass -Hibernate to hibernate instead (memory saved to disk)
  [switch] $DisableWake,          # default: wake events stay enabled. Pass -DisableWake to disable them.
  [switch] $Detach                # re-launch hidden + independent, return at once (lets Claude's turn finish first)
)

$ErrorActionPreference = 'Stop'

# --- Detach mode: spawn an independent hidden copy of ourself and return immediately ---------------------
# So the tool call / cmd that invoked us does not block until the machine wakes, and Claude's response
# (plus the task-done beep) reaches the user BEFORE the display powers off.
if ($Detach) {
  $childArgs = @('-NoProfile','-WindowStyle','Hidden','-ExecutionPolicy','Bypass',
                 '-File', $PSCommandPath, '-DelaySeconds', $DelaySeconds)
  if ($Hibernate)   { $childArgs += '-Hibernate' }
  if ($DisableWake) { $childArgs += '-DisableWake' }
  Start-Process -FilePath 'powershell.exe' -ArgumentList $childArgs -WindowStyle Hidden | Out-Null
  return
}

# --- Worker: wait the grace period, then suspend --------------------------------------------------------
if ($DelaySeconds -gt 0) { Start-Sleep -Seconds $DelaySeconds }

Add-Type -AssemblyName System.Windows.Forms

if ($Hibernate) { $state = [System.Windows.Forms.PowerState]::Hibernate }
else            { $state = [System.Windows.Forms.PowerState]::Suspend }

# force = TRUE  -> parity with LightSleep's SystemSleep(TRUE). MS documents bForce as "no effect" on Vista+,
#                 the real "force" is that Vista+ suspend is not vetoable. Kept TRUE for signature parity.
# disableWakeEvent = $DisableWake (default FALSE -> normal wake events remain armed).
[void][System.Windows.Forms.Application]::SetSuspendState($state, $true, [bool]$DisableWake)

# Note: SetSuspendState returns as soon as the request is ACCEPTED (the actual suspend is asynchronous),
# and a non-zero return is not a guarantee - a kernel driver can still veto. If the PC ever fails to
# sleep, run  powercfg /requests  (admin) to find the blocker, or  powercfg /energy  for a full report.
