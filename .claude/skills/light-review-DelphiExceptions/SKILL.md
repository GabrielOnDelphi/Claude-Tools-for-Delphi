---
name: light-review-DelphiExceptions
description: Audit every try..except in a Delphi project and judge each one - does it hide OUR bug from madExcept, or correctly absorb an environment failure (locked folder, full disk, dropped share)? Gives each block a verdict (NARROW / BLIND / SILENT / JUSTIFIED) plus the exact exception classes to narrow it to. Say "check the try/except blocks", "audit exception handling", "are we swallowing exceptions", "why did madExcept never report this".
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-review-DelphiExceptions - try..except Auditor

Every `except` block gets one question:

> **If this code failed because of a bug of ours, would we ever find out?**

A block that catches `Exception` catches our own access violations too. madExcept then never sees them, never mails a report, and the bug lives forever in every copy the users run. The opposite mistake costs just as much: letting a read-only folder crash the program and fill the mailbox with reports about a problem that is not ours to fix.

Both mistakes come from the same habit - writing `on E: Exception do` because it is shorter than naming the classes that can actually happen.

**Scope:** `except` blocks. `try..finally` never catches anything, so it is out of scope. Unit-test code is out of scope.

**Default is REPORT ONLY.** The skill changes nothing unless `$args` contains `fix`.

**Two folders are named all through this file. Both are paths on the author's machine - change them to yours.**

- `C:\Delphi\Delphi 13\source\` is the Delphi runtime library and VCL source that ships with RAD Studio. On a default install it sits under `C:\Program Files (x86)\Embarcadero\Studio\<version>\source\`. Every line number quoted from it is Delphi 13; check the line in your own version before you trust it.
- `C:\Projects\LightSaber\` is LightSaber, the author's own open-source Delphi library: https://github.com/GabrielOnDelphi/Delphi-LightSaber - free, MPL-2.0. Rules 4, 5, 6 and 8 name routines from it (`MessageErrorLog`, `MesajGeneric`, `ForceDirectoriesB`, `ForceDirectoriesE`). **Without LightSaber those four rules do not apply** - skip them, or point them at whatever your project uses to show an error and write a log line. The other six rules need nothing but Delphi.

---

## Step 1 - Find every block

Resolve the scope from `$args`: a file, a folder, or nothing (then use the current project's source folders, skipping `Output\`, `__history\`, `__recovery\`, `Win32\`, `Win64\` and any third-party folder).

Grep the `.pas` files. Run all three commands below from the scope folder, and **never drop the `-i`**.

```bash
# 1 - every except block
grep -rEin --include=*.pas "\bexcept\b" .

# 2 - the blind catch, the most common finding
grep -rEin --include=*.pas "\bon\s+([A-Za-z_][A-Za-z0-9_]*\s*:\s*)?Exception\s+do" .

# 3 - the bare catch: 'except' alone on a line, 'end' on the next one
grep -rEin -A1 --include=*.pas "^[[:space:]]*except[[:space:]]*$" . | grep -Ei "^[^:]*[-:][0-9]+[-:][[:space:]]*end[;[:space:]]*$"
```

**Why `-i` is not optional.** Delphi ignores letter case, and the house style in these projects writes keywords in capitals - `TRY`, `EXCEPT`, `ON E: Exception DO`, `RAISE`. Every code sample further down this file is written that way. A lower-case-only search finds none of them and reports no error. Measured on `C:\Projects\LightSaber\`: searching for `except` in lower case only finds 62 files where 96 contain one, because 157 occurrences of `EXCEPT` in capitals are invisible to it. A file written entirely in capitals is then reported as having no try..except block at all.

**Why command 2 allows any variable name, or none.** All three spellings below are legal Delphi and all three are blind catches. A pattern that hard-codes the single letter `E` followed by a colon finds only the first:

- `on E: Exception do` - the common spelling
- `on E2: Exception do` - the handler variable may be any identifier. Real case: `C:\Projects\LightSaber\FrameFMX\LightFmx.Common.Graph.pas` line 187
- `on Exception do` - no variable at all, which is valid. Real case: `C:\Projects\LightSaber\External\Exif\CCR.Exif.TiffUtils.pas` line 321

On LightSaber the narrow pattern finds 67 blind catches and the one above finds 90 - it was missing a quarter of them.

Count them and print the count before you start. Over ~120 blocks, work folder by folder and report per folder - do not try to hold the whole project in one answer.

**Read the whole procedure around each block, not just the block.** A catch is only judgeable against what the code before it does and what the caller expects after it.

---

## Step 2 - Sort the exception classes

The whole audit turns on one split: **the outside world refused** versus **we wrote a bug**.

### Not our fault - catching is correct

The program did everything right and something outside it said no. There is nothing for madExcept to report, and the user needs a plain message, not a crash dialog.

| Class | Where it is declared | Raised by |
|---|---|---|
| `EStreamError` | `C:\Delphi\Delphi 13\source\rtl\common\System.Classes.pas` line 205 | ancestor of the file-stream errors below - catch this one to cover them all |
| `EFCreateError` | same file, line 209 | a file could not be created (read-only folder, denied ACL, full disk) |
| `EFOpenError` | same file, line 210 | a file could not be opened (missing, locked by another program) |
| `EInOutError` | `C:\Delphi\Delphi 13\source\rtl\sys\System.SysUtils.pas` line 499 | runtime library input/output failure; carries `ErrorCode` |
| `EOSError` | same file, line 579 | what `RaiseLastOSError` raises after a failed Windows API call; carries `ErrorCode` |
| `EInOutArgumentException` | same file, line 516 | a path that is empty or holds characters invalid in a path - raised by `TDirectory.CreateDirectory`, so by `LightCore.IO.ForceDirectoriesE` too. **Descends from `EArgumentException`, NOT from `EInOutError` - naming `EInOutError` does not catch it.** |

`EInOutError` also covers `EFileNotFoundException` (line 511) and `EPathNotFoundException` (line 513), so those need no separate handler.

**Never narrow a block to `EArgumentException` itself.** Two of its descendants sit one line apart in the runtime library and have opposite verdicts: `EInOutArgumentException` (line 516) is a bad path the user typed and must be caught, while `EArgumentOutOfRangeException` (line 469) is our own bug and must reach madExcept. Catching the parent swallows both.

Add per project, after checking the declaration yourself: Indy socket errors (`EIdSocketError`), database connection errors, `EPrinter`.

### Our bug - catching is wrong, let madExcept mail it

These cannot be caused by a locked folder. Every one of them means the code is wrong.

`EAccessViolation` (nil pointer, freed object) - `EInvalidPointer` (double free, corrupt heap) - `EListError` (index past the end of a `TList` or `TStrings`) - `ERangeError` and `EArgumentOutOfRangeException` - `EIntOverflow`, `EDivByZero`, `EZeroDivide` - `EInvalidCast` (a bad `as`) - `EAbstractError` - `EAssertionFailed` - `EStackOverflow` (runaway recursion).

### Depends on where the value came from

- **`EConvertError`** - `StrToInt` on garbage. If the string came from a user, a file or a web answer, it is bad data and catching is right. If our own code built it, it is our bug.
- **`EOutOfMemory`** - a 32-bit process asked for more than the address space has (a huge image: not our fault), or something leaks (our fault).

---

## Step 3 - Give the block a verdict

| Verdict | What it means | Action |
|---|---|---|
| **NARROW** | Catches only named classes from the "not our fault" list. | Nothing. This is the target shape. |
| **BLIND** | `on E: Exception do` or a bare `except`, catching everything including our bugs. | Rewrite: name the classes that can really happen here. |
| **SILENT** | Swallows and does nothing - no log, no message, no re-raise. The worst kind: the program keeps running in a state nobody understands and nobody ever learns why. | Always a finding. |
| **JUSTIFIED** | Blind on purpose, and a comment in the code says why. | Nothing, if the reason is one of the cases in "What NOT to flag". |

Delphi cannot name two classes in one handler, so a narrowed block repeats the handler:

```pascal
VAR
  SaveFailed: Boolean;
  ErrMsg: string;
begin
  SaveFailed:= FALSE;
  TRY
    SaveConfig;
  EXCEPT
    ON E: EStreamError DO begin SaveFailed:= TRUE; ErrMsg:= E.Message; end;  { file cannot be created or opened }
    ON E: EInOutError  DO begin SaveFailed:= TRUE; ErrMsg:= E.Message; end;  { runtime library I/O error }
    ON E: EOSError     DO begin SaveFailed:= TRUE; ErrMsg:= E.Message; end;  { RaiseLastOSError after a failed API call }
  END;                                                                       { anything else flies out to madExcept }

  if SaveFailed then
   begin
     MessageErrorLog('Could not save to' + CRLF + FFolderPath + CRLF + CRLF + ErrMsg, 'Save failed: ' + ErrMsg);
     EXIT;
   end;
```

A `Boolean` flag rather than testing `ErrMsg <> ''`, because an exception is allowed to carry an empty message.

---

## The ten rules

### 1. An exception that escapes a close handler makes the form immortal

In `OnCloseQuery`, `OnClose`, `OnDestroy` and `FormClose`, every attempt to close raises again: madExcept box, click OK, form still open, try again, same box. Only Task Manager ends it.

**This is the one place where a blind catch is right.** Catch everything, log it, and let the form close. Same for a destructor and for a `finalization` section.

When judging a raise in an ordinary button handler, check whether the button carries a `ModalResult` set at design time or in code.

**If it does not**, an escaping exception is harmless: the VCL message loop catches it, madExcept reports it, and the form stays open with the user's data intact - usually exactly what you want, at no cost.

**If it does, an escaping exception is worse than any blind catch on this page: the dialog closes and tells its caller the work succeeded.** Three lines of VCL source, in the order they run:

1. `TCustomButton.Click` (`C:\Delphi\Delphi 13\source\vcl\Vcl.StdCtrls.pas` line 5983) assigns `Form.ModalResult := ModalResult` **before** line 5984 calls `inherited Click`, which is what fires your `OnClick`. The form's result is already set when your handler starts.
2. Your handler raises. `TWinControl.MainWndProc` (`C:\Delphi\Delphi 13\source\vcl\Vcl.Controls.pas` line 10977) catches it and calls `Application.HandleException` - madExcept shows the box and mails the report.
3. Control returns to the loop inside `TCustomForm.ShowModal` (`C:\Delphi\Delphi 13\source\vcl\Vcl.Forms.pas` line 9996), which tests nothing but `if ModalResult <> 0 then CloseModal;`.

So the user sees an error box, the dialog closes anyway, and the calling code reads `mrOk` for work that never finished. No verdict in the table above describes this - flag it as BLIND with the note "closes on mrOk after an error".

The fix is one line at the top of the handler's own `except`, or clearing the design-time `ModalResult` and closing the form by hand at the end of the handler:

```pascal
EXCEPT
  ON E: EStreamError DO
    begin
      ModalResult:= mrNone;    { STOP the dialog from closing - it was already set to mrOk before this handler ran }
      MessageErrorLog('Could not save:' + CRLF + E.Message);
    end;
END;
```

### 2. A blind catch steals `Abort`

`Abort` raises `EAbort` (`EAbort = class(Exception)`, `C:\Delphi\Delphi 13\source\rtl\sys\System.SysUtils.pas` line 482). It is the runtime library's way to cancel an operation with no noise. `TApplication.HandleException` in `C:\Delphi\Delphi 13\source\vcl\Vcl.Forms.pas` reads `if not IsClass(O, EAbort) then` before showing anything - the VCL deliberately shows nothing for it.

A blind `on E: Exception do MessageError(E.Message)` breaks that: the user cancels and gets an error box saying "Operation aborted". Fix: put `ON E: EAbort DO RAISE;` as the first handler, or narrow the block.

### 3. Re-raise with a bare `raise;` - never `raise E;`

Two different runtime routines, and the difference is one argument. In `C:\Delphi\Delphi 13\source\rtl\sys\System.pas`, both are declared once per platform - Win32 at lines 3712-3713, Win64 at lines 3724-3726:

- bare `raise;` compiles to `_RaiseAgain`, which reads the **original** address out of the raise frame (`ExceptAddr := CurRaiseFrame^.ExceptAddr`) and passes it on.
- `raise E;` compiles to `_RaiseExcept`, which passes `ReturnAddress` - the **current** address, which is the `except` block itself.

So `raise E;` makes madExcept's report point at the `except` block instead of at the line that really failed.

Log-then-rethrow is a good pattern and is never a finding:

```pascal
EXCEPT
  ON E: Exception DO
    begin
      AppDataCore.LogError('Import failed: ' + E.Message);
      RAISE;      { madExcept still gets it, with the original stack }
    end;
END;
```

### 4. Show the user AND write the log - with one routine

The message box dies the moment the user clicks OK. The log survives: `AppDataCore.LogError` writes into the RAM log, and the RAM log saves itself to disk (`C:\Projects\LightSaber\LightCore.LogRam.pas` line 802 writes `PeriodicLogSave.logbin` into the AppData folder). That line is worth keeping even for a failure that is not our fault - not for the failure itself, but for the context it gives to the next real crash report sitting three lines below it.

So do both, through one call. **The routine already exists - do not write another one:**

- VCL: `MessageErrorLog` in `C:\Projects\LightSaber\FrameVCL\LightVcl.Common.Dialogs.pas` (declared line 56, body line 157).
- FMX: `MessageErrorLog` in `C:\Projects\LightSaber\FrameFMX\LightFmx.Common.Dialogs.pas` (declared line 37, body line 125).

```pascal
procedure MessageErrorLog(CONST MessageText: string; CONST LogText: string= ''; CONST Title: string= '');
```

Pass `LogText` only when the dialog text is long or spread over several lines - the log wants one short line. Leave it empty and the dialog text itself is logged. The routine already guards `AppDataCore` against NIL, so the caller does not repeat that check. The third parameter is named `Title` in the VCL unit and `Caption` in the FMX unit.

Both write the log line even in test mode, where no dialog is shown at all - see rule 5.

### 5. Never `MessageDlg` - use the LightSaber routines

`C:\Projects\LightSaber\FrameVCL\LightVcl.Common.Dialogs.pas` has `MessageError`, `MessageWarning`, `MessageInfo`, `MesajYesNo` and `MesajErrDetail`. Prefer them, for one concrete reason beyond consistency: `MesajGeneric` (line 91 of that unit) reads `if TAppDataCore.TEST_MODE then EXIT(0)` at lines 96-97 - no dialog appears during unit tests. A `MessageDlg` in the same place hangs the test run forever, waiting for a click nobody will make.

`MesajGeneric` also prefixes the caption with `Application.Title`, so the box says "BioniX - Error" instead of a bare form name.

### 6. In a unit advertised as reusable, guard `AppDataCore`

`AppDataCore` is a global that each application creates by hand in its `.dpr` (`AppDataCore := TAppDataCore.Create('MyCoolApp')`), and it is set back to NIL during shutdown - the comment at `C:\Projects\LightSaber\LightCore.AppData.pas` line 186 says the `finalization` of `LightVcl.Visual.AppData` frees it and nils the variable.

So in a unit whose header claims it works outside this project, write `if AppDataCore <> NIL then AppDataCore.LogError(...)`. That is LightSaber's own habit - `C:\Projects\LightSaber\FrameFMX\LightFmx.Common.Graph.pas` line 64 reads `if Assigned(AppDataCore) then AppDataCore.LogError(...)`, and thirteen other LightSaber units do the same - fourteen in total.

Inside an application unit that can only ever run in that application, the guard is dead code. Flag it only when the unit header makes no reusability claim.

### 7. To keep running AND still get the report: `madExcept.HandleException`

Sometimes the code must survive the failure but you still want the crash mail. The comment above the declaration in `madExcept.pas` line 1464 (the `Sources` folder of your madExcept install) says it plainly: *"this calls our exception handler, you can e.g. call this from a try..except"*.

```pascal
EXCEPT
  ON E: Exception DO
    begin
      madExcept.HandleException;   { every parameter is optional }
      Result:= FALSE;
    end;
END;
```

Use it where rule 3's bare `raise;` is not possible - inside a thread, a callback, or a plug-in boundary.

### 8. Some runtime library calls return FALSE instead of raising - a try..except catches nothing

`DeleteFile`, `RenameFile`, `CreateDir`, `RemoveDir`, `SetCurrentDir` and the Windows API calls (`MoveFileEx`, `CopyFile`) all return `False` on failure and raise nothing. Wrapping them in `try..except` protects nothing. Inside every try block, flag each one whose `Boolean` result is thrown away, and test the result instead.

**Creating a folder: three routines, and only one of them raises.** Check which one the unit actually calls before you write anything about it.

- `System.SysUtils.ForceDirectories(Dir: string): Boolean` - returns `False` when the folder cannot be created. It raises only when the path is an empty string, and then it raises `EInOutError` (`C:\Delphi\Delphi 13\source\rtl\sys\System.SysUtils.pas` line 10362). So a `try..except` around it catches nothing in every other failure.
- `LightCore.IO.ForceDirectoriesB(CONST Folder: string): Boolean` - **never raises** (`C:\Projects\LightSaber\LightCore.IO.pas` line 205, body at line 765). `TRUE` = the folder is there now, created or already existing. `FALSE` = it is not: empty or invalid path, path over MAX_PATH, missing or write-protected drive, no write permission.
- `LightCore.IO.ForceDirectoriesE(CONST Folder: string)` - **raises**, and the exception already carries the Windows reason text (`C:\Projects\LightSaber\LightCore.IO.pas` line 204, body at line 789). It is a thin wrapper around `TDirectory.CreateDirectory`. Use it for "I am about to write a file in here", where carrying on after a failure is pointless.

Pick by what the caller needs to do next:

```pascal
{ The caller decides what happens next - so ask, do not raise. }
if NOT ForceDirectoriesB(FFolderPath)
then MessageErrorLog('Cannot create the folder:' + CRLF + FFolderPath, 'Cannot create folder: ' + FFolderPath);

{ Carrying on is pointless - so let it raise, with the Windows reason text already in it. }
ForceDirectoriesE(FFolderPath);
```

Do not append `SysErrorMessage(GetLastError)` to a message after `ForceDirectoriesB`. That routine calls `System.SysUtils.ForceDirectories`, **deliberately ignores its result**, and then answers `DirectoryExists(Folder)` instead. The comment at `C:\Projects\LightSaber\LightCore.IO.pas` line 753 says why: when another thread creates the same folder in the gap between the runtime library's own existence check and its `CreateDir` call, the runtime library answers `FALSE` for a folder that does exist. Asking the file system afterwards is the only answer immune to that race, and BioniX depends on it because several background threads create thumbnail folders at once. The cost is that by the time you see the `FALSE`, the last Windows error code no longer belongs to the failure.

**What `ForceDirectoriesE` raises** - all four come out of `TDirectory.CreateDirectory`, and three of the four are covered by catching `EInOutError`:

| Class | Ancestor | Caught by `EInOutError`? |
|---|---|---|
| `EPathTooLongException` | `EInOutError` (`System.SysUtils.pas` line 507) | yes |
| `EDirectoryNotFoundException` | `EInOutError` (line 509) | yes |
| `EInOutError` - anything else, message = `SysErrorMessage(GetLastError)` | - | yes |
| `EInOutArgumentException` - path empty, or holding characters invalid in a path | **`EArgumentException`** (line 516) | **NO - you must name it** |

**The general rule this taught:** reading the runtime library source is not enough. A project can shadow or replace any name, and a name that was there last year may be gone. Check the unit's own uses clause and the current declaration before you write a fact about a routine.

### 9. An exception leaving a thread's `Execute` is absorbed by the runtime library

`C:\Delphi\Delphi 13\source\rtl\common\System.Classes.pas` line 16429 wraps the call in a blind catch of its own:

```pascal
try
  Thread.Execute;
except
  Thread.FFatalException := AcquireExceptionObject;
end;
```

It is stored in the read-only property `TThread.FatalException` (line 1982 of the same file) and freed when the thread object dies. Nobody sees it unless somebody reads that property in `OnTerminate`.

In a madExcept build the opposite problem appears: madExcept boxes the thread exception, and a modal box owned by a background thread looks to the user like a full application freeze. BioniX documents exactly this at `BxAIProviderComfyUI.pas` line 630, inside the comment block that runs from line 626.

So a procedure called from a worker thread should return an error value, not raise. Flag any `raise` on a path reachable from `TThread.Execute` that has no handler before the thread boundary.

### 10. Catch inside the loop or outside it - decide, do not default

Processing a list of independent items (files, layers, images): catch **inside** the loop, so one bad item does not abort the other ninety-nine. Items that form one transaction (all layers of one config): catch **outside**, so a half-written result is never kept. A blind catch wrapped around the whole loop when the items are independent is a finding, even when the classes are narrow.

**Moving the catch inside the loop does not excuse it from the other rules.** A handler inside a loop must still do all three of these, or it is a SILENT block wearing a per-item disguise:

1. **Name its classes.** A bare catch inside a loop counts our own access violation as "one more bad file" and keeps going through the remaining ninety-eight.
2. **Log each failed item, with its name.** A count alone cannot be acted on - "7 files failed" tells nobody which seven.
3. **Report the total once the loop ends.** A loop that skips five of ninety-nine files and returns quietly is the SILENT verdict from the table above.

This is a real block in LightSaber, at `C:\Projects\LightSaber\LightCore.IO.pas` lines 2071-2073, and it fails points 1 and 2:

```pascal
EXCEPT
  Inc(Result);  { Count failed copies }
END;
```

It is inside the loop and it does return a total, so it satisfies point 3. But it names no class, so a bug of ours is counted as a failed file and never reaches madExcept, and it logs nothing, so nobody can find out which file failed or why.

---

## Step 4 - Report

Write the findings to `<project root>\ExceptionAudit <YYYY-MM-DD>.md`. Change no code unless `$args` contains `fix`.

Summary table first, one row per finding, worst first:

| # | File : line | Procedure | Verdict | Why | Fix |
|---|---|---|---|---|---|
| 1 | `BxParallaxEditor.pas:1207` | `btnSaveClick` | BLIND | `on E: Exception` also eats an access violation from `FLayers[]`; madExcept never mails it | Narrow to `EStreamError`, `EInOutError`, `EOSError` |

Then one short block per finding: the code as it stands, and the code as it should read.

End the file with this line, exactly:

> Audit produced by <model name>. Counter-analysis must run in a NEW session - re-open this file there and ask for the line of code that proves or disproves each finding.

**Why a new session:** re-checking findings in the session that produced them is measured as the worst of the four ways tested - 21.7% against 28.6% for a fresh session, and the most false alarms, 4.4 per document against 3.1 (Song, arXiv:2603.12123). Do not counter-analyze your own report here, and do not spawn a subagent to do it - a subagent checking the parent scored 23.8%, no better than not separating at all.

## What NOT to flag

- `try..finally`. It does not catch.
- A blind catch in `OnCloseQuery`, `OnClose`, `OnDestroy`, a destructor or a `finalization` section - rule 1 says that is correct.
- A blind catch that logs and then re-raises with a bare `raise;` - madExcept still gets it, with the right stack.
- A blind catch at a boundary an exception must not cross: a `stdcall` callback the Windows API calls back into, a DLL export, a COM method. There the exception must become a return code.
- A function whose documented contract is to return an error string and never raise - read the comment above it before flagging.
- Test code, demo projects, and third-party source.

Report a count of the blocks you looked at and cleared, so the numbers add up. A block you were unsure about goes into the report marked UNSURE, with the question you could not answer - never silently dropped.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
