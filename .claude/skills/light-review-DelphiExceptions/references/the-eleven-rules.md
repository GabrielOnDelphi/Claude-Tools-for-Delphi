# The eleven rules - light-review-DelphiExceptions

Loaded from `SKILL.md` when a block needs one of these rules. `SKILL.md` carries the index; this file carries the argument and the evidence for each rule.

**Every line number and count in this file was measured on a real tree on the date given, and source moves.** LightSaber changed under this skill twice in two days - once two hours after a rule was written. Before you quote a line number from here into a finding, open the file and check it. Before you repeat a count, re-measure it. A rule whose *argument* is sound can carry a line number that is stale by one, and a reader who opens that line finds a comment and stops trusting the whole report.

## Index

1. An exception that escapes a close handler makes the form immortal
2. A blind catch steals `Abort`
3. Re-raise with a bare `raise;` - never `raise E;`
4. Show the user AND write the log - with one routine
5. Never `MessageDlg` - use the LightSaber routines
6. Guard the global - but only where it is not already guarded for you
7. To keep running AND still get the report: `madExcept.HandleException`
8. Some runtime library calls return FALSE instead of raising - a try..except catches nothing
9. An exception leaving a thread's `Execute` is absorbed by the runtime library
10. Catch inside the loop or outside it - decide, do not default
11. Measure the damage before you argue about it: madExcept's hidden-exception handler

---

## The eleven rules

### 1. An exception that escapes a close handler makes the form immortal

In `OnCloseQuery`, `OnClose`, `OnDestroy` and `FormClose`, every attempt to close raises again: madExcept box, click OK, form still open, try again, same box. Only Task Manager ends it.

**This is the one place where a blind catch is right.** Catch everything, log it, and let the form close. Same for a destructor and for a `finalization` section.

**The log is a separate finding, not part of the verdict.** Row 1 of the verdict table clears the *catch* in these places without asking whether it logs, and that is deliberate - the catch is right either way. An empty `EXCEPT END;` in a destructor is therefore JUSTIFIED **and** a breach of this rule: one line in the report for the missing log, none for the catch. Do not let the cleared verdict swallow the second finding, and do not downgrade the verdict because the log is missing.

When judging a raise in an ordinary button handler, check whether the button carries a `ModalResult` set at design time or in code.

**If it does not**, an escaping exception is harmless: the VCL message loop catches it, madExcept reports it, and the form stays open with the user's data intact - usually exactly what you want, at no cost.

**If it does, an escaping exception is worse than any blind catch on this page: the dialog closes and tells its caller the work succeeded.** Three lines of VCL source, in the order they run:

1. `TCustomButton.Click` (`C:\Delphi\Delphi 13\source\vcl\Vcl.StdCtrls.pas` line 5983) assigns `Form.ModalResult := ModalResult` **before** line 5984 calls `inherited Click`, which is what fires your `OnClick`. The form's result is already set when your handler starts.
2. Your handler raises. `TWinControl.MainWndProc` (`C:\Delphi\Delphi 13\source\vcl\Vcl.Controls.pas` line 10977) catches it and calls `Application.HandleException` - madExcept shows the box and mails the report.
3. Control returns to the loop inside `TCustomForm.ShowModal` (`C:\Delphi\Delphi 13\source\vcl\Vcl.Forms.pas` line 9996), which tests nothing but `if ModalResult <> 0 then CloseModal;`.

So the user sees an error box, the dialog closes anyway, and the calling code reads `mrOk` for work that never finished. No verdict in the table above describes this - flag it as BLIND with the note "closes on mrOk after an error".

**None of the five searches in Step 1 can find this one, because there is no `except` here at all** - the fault is an exception nobody caught, in a handler on a button that carries a `ModalResult`. It needs a pass of its own, and it is cheap: run the Grep tool with `glob: *.dfm` over the scope, pattern `ModalResult = mr(Ok|Yes|All|Retry|Ignore)`, and for every button it names, open the unit beside that form and read the button's `OnClick`. Only handlers that can raise matter - one that does nothing but set a variable is safe. Buttons set to `mrCancel`, `mrNo` or `mrAbort` are safe too: the caller already treats those as "did not happen".

Do this pass once per project, not once per block, and report what it finds in the same file as the rest.

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

**The symptom to recognise, reported from the field.** In the Delphi-PRAXiS thread "Delphi daily WTF / antipattern / stupid code thread" (topic 5386), Fr0sT.Brutal lists `raise E;` inside an `on E: Exception do` handler as an antipattern and describes what it does downstream: *"Gives scary and mystic AV somewhat later after the problematic line in OS callstack. Real PITA to find and fix."* So a `raise E;` you leave in place does not only mislabel the address - it can become the source of a *new* crash report that has nothing to do with the original failure. **[UNVERIFIED]** - the address behaviour above was read from the Delphi source, but this second effect is one developer's field report and was not checked against the runtime library. Either way the instruction is the same: write the bare `raise;`.

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

- VCL: `MessageErrorLog` in `C:\Projects\LightSaber\FrameVCL\LightVcl.Common.Dialogs.pas` (declared line 57, body line 158; 2026-09-05).
- FMX: `MessageErrorLog` in `C:\Projects\LightSaber\FrameFMX\LightFmx.Common.Dialogs.pas` (declared line 38, body line 126; 2026-09-05).

```pascal
procedure MessageErrorLog(CONST MessageText: string; CONST LogText: string= ''; CONST Title: string= '');
```

Pass `LogText` only when the dialog text is long or spread over several lines - the log wants one short line. Leave it empty and the dialog text itself is logged. The routine already guards `AppDataCore` against NIL, so the caller does not repeat that check. The third parameter is named `Title` in the VCL unit and `Caption` in the FMX unit.

Both write the log line even in test mode, where no dialog is shown at all - see rule 5.

### 5. Never `MessageDlg` - use the LightSaber routines

`C:\Projects\LightSaber\FrameVCL\LightVcl.Common.Dialogs.pas` has `MessageError`, `MessageWarning`, `MessageInfo`, `MesajYesNo` and `MesajErrDetail`. Prefer them, for one concrete reason beyond consistency: `MesajGeneric` (line 92 of that unit) reads `if TAppDataCore.Unattended then EXIT(0)` at lines 97-98 - no dialog appears during unit tests. (The property was called `TEST_MODE` until 2026-09-04 and the old name no longer compiles; `LightCore.AppData.pas` line 123 records the rename.) A `MessageDlg` in the same place hangs the test run forever, waiting for a click nobody will make.

`MesajGeneric` also prefixes the caption with `Application.Title`, so the box says "BioniX - Error" instead of a bare form name.

### 6. Guard the global - but only where it is not already guarded for you

`AppDataCore` is a global that each application creates by hand in its `.dpr` (`AppDataCore := TAppDataCore.Create('MyCoolApp')`), and it is set back to NIL during shutdown: the `finalization` of `LightVcl.Visual.AppData` / `LightFmx.Common.AppData` frees it and nils the variable, as the comment at `C:\Projects\LightSaber\LightCore.AppData.pas` lines 178-181 says. A handler is the most likely place in the program to run during shutdown, so this is a handler problem before it is anything else.

**Split the calls in two before you write a finding. The two halves have opposite answers.**

**Logging needs no guard.** `TAppDataCore.LogError`, `LogWarn`, `LogInfo`, `LogMsg`, `LogBold`, `LogHint`, `LogImpo`, `LogVerb`, `LogEmptyRow` and `LogClear` are declared `static` at `LightCore.AppData.pas` lines 188-197 and each one tests the global itself (`if AppDataCore <> NIL then AppDataCore.doLogError(Msg);`, lines 686-689). `AppDataCore.LogError('x')` and `TAppDataCore.LogError('x')` are both safe on a NIL global. Writing `if AppDataCore <> NIL then AppDataCore.LogError(...)` in front of one is dead code - do not ask for it and do not flag its absence. Sixteen LightSaber units still write it out of habit; that is history, not a rule.

`static` is what makes this work and it is worth knowing why, because the same class without it behaves the opposite way. A class method **without** `static` carries a hidden `Self`; called through a NIL object reference it reads the class pointer out of that NIL object and raises `EAccessViolation` at address 0 - measured on Delphi 13, Win32 and Win64. With `static` there is no hidden `Self`, nothing is read, and the call is safe.

**Instance members do need the guard.** `AppDataCore.RamLog`, `AppDataCore.IniFile` and anything else reached through the object itself will raise on a NIL global. Write `if Assigned(AppDataCore) then ...`, as `C:\Projects\LightSaber\FrameFMX\LightFmx.Common.Graph.pas` line 64 does. The one unguarded case in LightSaber today is `C:\Projects\LightSaber\FrameVCL\FormSkinsDisk.pas` line 131.

**The general rule, for a project that is not LightSaber:** open the declaration of what the handler calls before you require anything. A routine that guards itself needs no guard at the call site, and you cannot tell which kind you have from the call - `AppDataCore.LogError(...)` and `AppDataCore.RamLog.AddError(...)` look alike and behave differently.

### 7. To keep running AND still get the report: `madExcept.HandleException`

Sometimes the code must survive the failure but you still want the crash mail. The comment above the declaration in `C:\Delphi\IDE madShi 510\madExcept\Sources\madExcept.pas` line 1464 says it plainly: *"this calls our exception handler, you can e.g. call this from a try..except"*.

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

**What `ForceDirectoriesE` raises** - all five come out of `TDirectory.CreateDirectory`, and only three of the five are covered by catching `EInOutError`:

| Class | Ancestor | Caught by `EInOutError`? |
|---|---|---|
| `EPathTooLongException` | `EInOutError` (`System.SysUtils.pas` line 507) | yes |
| `EDirectoryNotFoundException` | `EInOutError` (line 509) | yes |
| `EInOutError` - anything else, message = `SysErrorMessage(GetLastError)` | - | yes |
| `EInOutArgumentException` - path empty, or holding characters invalid in a path | **`EArgumentException`** (line 516) | **NO - you must name it** |
| `ENotSupportedException` - a colon anywhere after the drive letter, e.g. a user typing `C:\Data\12:30` | **`Exception`** (line 472) | **NO - you must name it** |

The fifth row is the one everybody misses, this skill included until 2026-09-05. `TDirectory.CreateDirectory` (`C:\Delphi\Delphi 13\source\rtl\common\System.IOUtils.pas` line 1170) calls `CheckCreateDirectoryParameters`, which calls `InternalCheckDirPathParam` (line 1937), which ends with:

```pascal
{$IFDEF MSWINDOWS}
  { Windows-only: Check for valid colon char in the path }
  if not TPath.HasPathValidColon(Path) then
    raise ENotSupportedException.CreateRes(@SPathFormatNotSupported);
{$ENDIF MSWINDOWS}
```

`ENotSupportedException` descends straight from `Exception` (`System.SysUtils.pas` line 472), so nothing else in this table catches it, and a path typed by a user is exactly where a stray colon comes from. The same four-class list without it is repeated in LightSaber's own source comment at `C:\Projects\LightSaber\LightCore.IO.pas` lines 783-787 - so the gap sits in two places and fixing one does not fix the other.

**The general rule this taught:** reading the runtime library source is not enough, and reading only the routine you called is not enough either. Follow the calls it makes down to the bottom - the fifth class above is raised three levels below `ForceDirectoriesE`. A project can also shadow or replace any name, and a name that was there last year may be gone, so check the unit's own uses clause and the current declaration before you write a fact about a routine.

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

In a madExcept build the opposite problem appears: madExcept boxes the thread exception, and a modal box owned by a background thread looks to the user like a full application freeze. BioniX documents exactly this at `C:\Projects\BioniX\SourceCode\BioniX VCL\BxAIProviderComfyUI.pas` line 630, inside the comment block that runs from line 626.

So a procedure called from a worker thread should return an error value, not raise. Flag any `raise` on a path reachable from `TThread.Execute` that has no handler before the thread boundary.

**`Execute` is not the only door into this.** The same fault arrives through every routine that takes an anonymous method and runs it later, on a stack that no longer has your `try..except` on it:

- **`TThread.ForceQueue` - always defers.** The closure runs on a later turn of the main message loop, inside `CheckSynchronize`, which is **outside** any `try..except` that was open when you posted it. This is the only one of the three `TThread` routines that behaves this way from every thread.
- **`TThread.Queue` and `TThread.Synchronize` - it depends which thread you call them from, and the difference is not visible at the call site.** `TThread.Synchronize` (`C:\Delphi\Delphi 13\source\rtl\common\System.Classes.pas` line 17085) begins `if (CurrentThread.ThreadID = MainThreadID) and not (QueueEvent and ForceQueue) then` and runs the closure **inline** at lines 17094-17097. `Queue` passes `ForceQueue = False` (lines 17023 and 17037), so on the main thread both run the closure immediately, inside the caller's `try..except`. Called from a worker thread they do defer - and `Synchronize` then re-raises the closure's exception back in the worker (lines 17128-17129), where the worker's own handler catches it. So only a `Queue` posted from a worker escapes the way this rule describes.
- **`TTask.Run` - the exception is captured into the task and only re-raised if somebody calls `Wait` on it.** Nobody usually does.
- **`TParallel.For` is not in this list - it re-raises by itself.** `TParallel.ForWorker` (`C:\Delphi\Delphi 13\source\rtl\common\System.Threading.pas`) calls `RootTask.Start.Wait;` at line 1489 inside its own `try..except` and ends that handler with `RootTaskObj.CheckFaulted;` at line 1496; `TTask.CheckFaulted` (lines 1901-1911) reads `Exception := GetExceptionObject; if Exception <> nil then begin SetRaisedState; raise Exception; end;`. So a `try..except` wrapped around `TParallel.For` **does** see the loop's exception. Do not flag it.

**And when a closure does escape, it is not silent.** Inside `CheckSynchronize`, lines 16371-16375:

```pascal
            except
              if not SyncProc.Queued then
                SyncProc.SyncRec.FSynchronizeException := AcquireExceptionObject
              else if Assigned(ApplicationHandleException) then
                ApplicationHandleException(SyncProc.SyncRec.FThread);
            end;
```

For a **queued** closure the exception goes to `Application.HandleException`, which is where madExcept sits - so it is reported, not parked in a field nobody reads. The heading of this rule ("absorbed by the runtime library") is true of `TThread.Execute` and of `TTask.Run`, and false of a queued closure. The finding is still real, because the closure escapes the `try..except` the author thought protected it and lands in a madExcept box the author did not expect - but write the finding as "reaches madExcept from the wrong place", never as "disappears".

The trap is that the code reads as protected. Real case in LightSaber: `C:\Projects\LightSaber\FrameFMX\LightFmx.Common.CrashHandler.pas` posts a closure with `TThread.ForceQueue` from inside a `try..except` (line 170 on 2026-09-05), and the closure needs its own `try..except` because the outer one has long since unwound by the time it runs. It has one, at lines 179-180, and the comment at 172-175 says exactly why. Find it by that comment - this block has moved three times in two days.

So: **when a `try` block posts a closure, the closure is not inside the try.** Judge it as its own block, and if it has no handler of its own, that is a finding.

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

### 11. Measure the damage before you argue about it: madExcept's hidden-exception handler

Everything above is read from the source. There is also a way to make the program itself tell you which of its `try..except` blocks are firing, and on what - including the ones that are eating your own bugs right now, in a build you already have.

madExcept calls an exception that some `try..except` already handled a **hidden exception**, and it can be told to report those too. The help page at `http://help.madshi.net/madExceptUnit.htm` says it in these words:

> *"Sometimes you want to be notified even about exceptions, which are handled by a try..except statement somewhere. Normally such exceptions are hidden from you and the user. ... Please note, however, that this makes sense only for debugging. You should not enable this feature by default in a shipping product, because otherwise this option does cost time during the normal program flow, while all the other features of madExcept cost time only when a 'real' exception occurs."*

The routine to call:

```pascal
procedure RegisterHiddenExceptionHandler (hiddenHandler: TExceptEvent; sync: TSyncType);
```

Your handler is called with its `handled` parameter already set to `TRUE`, so doing nothing means you are only notified and the program carries on exactly as before. Setting `handled` to `FALSE` makes the exception behave like a normal, unhandled one.

**How to use it for this audit.** Wrap the registration in the debug build only, log the class name and the address, run the program through a normal session, and read the log. Anything that appears there is a block your `try..except` is absorbing today. An `EAccessViolation` or an `EListError` in that log is a bug of yours that madExcept has never mailed you and never will.

Two warnings, both from the quote above:

- **Never ship it enabled.** It costs time on every exception during normal running, not only on a crash.
- Do not read `IMEException.BugReport` inside the handler unless you need the stack, because the report is only built at the moment you touch that property, and building it is slow.

This does not replace the source audit - it finds only the blocks that happened to fire during your session, and says nothing about the ones that never ran. It is the evidence you show somebody who says "that catch has never hidden anything".

---

