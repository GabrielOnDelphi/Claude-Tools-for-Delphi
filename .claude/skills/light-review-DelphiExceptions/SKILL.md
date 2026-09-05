---
name: light-review-DelphiExceptions
description: Audit every try..except in a Delphi project and judge each one - does it hide OUR bug from madExcept, or correctly absorb an environment failure (locked folder, full disk, dropped share)? Gives each block a verdict (JUSTIFIED / SILENT / BLIND / NARROW / UNSURE) plus the exact exception classes to narrow it to. Say "check the try/except blocks", "audit exception handling", "are we swallowing exceptions", "why did madExcept never report this".
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

**Files in this skill folder** (`c:\Users\<you>\.claude\skills\light-review-DelphiExceptions\`):

| File | What it is | When it is read |
|---|---|---|
| `SKILL.md` | This file: the five searches, the exception-class split, the verdict table, the report format. | Always |
| `references/the-eleven-rules.md` | The argument and the evidence behind each of the eleven rules - the Delphi runtime library facts, the madExcept behaviour, the LightSaber routines. | When a block touches one of the eleven; the index below says which |
| `scripts/find-bare-catches.py` | The scanner for search 3. Blanks comments and string literals, then walks tokens to find every `except` with no `on ... do` handler and sort it into six piles. | Run, never read - and never retyped |
| `scripts/test-find-bare-catches.py` | The scanner's self-test: seventeen Delphi blocks with the right answer written on each `except` line. | After any change to the scanner - it must print `All green.` |
| `evals/evals.json` | The three test prompts this skill is checked against, and what each one must produce. | Before publishing a change |

**Default is REPORT ONLY.** The skill changes nothing unless `$args` contains `fix`.

---

## Step 1 - Find every block

Resolve the scope from `$args`: a file, a folder, or nothing (then use the current project's source folders, skipping `Output\`, `__history\`, `__recovery\`, `Win32\`, `Win64\` and any third-party folder).

Five searches. Write the scope as a full absolute path in every one of them - do not `cd` into the folder first and then search `.`, because searches 3 to 5 are run with the **Grep tool**, which takes a path and never sees a working folder at all.

Searches 1 and 2 are plain `grep`. **Never drop the `-i`.**

```bash
# 1 - every except block
grep -rEin --include=*.pas "\bexcept\b" "c:/Projects/YourProject"

# 2 - the blind catch, the most common finding
grep -rEin --include=*.pas "\bon\s+([A-Za-z_][A-Za-z0-9_]*\s*:\s*)?Exception\s+do" "c:/Projects/YourProject"
```

**Search 3 - the bare catch. This is the one that finds the most, and no regular expression can do it.**

A bare catch is an `except` with **no `on ... do` handler at all**. Its body can be anything: nothing, a comment, `FreeAndNil(Result);`, `Result:= FALSE;`, `Inc(Result);`. So the thing that defines it is a **negative** - what is *not* the next thing after the `except` - and a regular expression cannot express that without lookahead, which the Grep tool's engine does not have.

Any attempt to define it by its shape misses almost all of them. Measured on `C:\Projects\LightSaber\` (2026-09-05):

| How the search is written | Bare catches found |
|---|---|
| `except` with `end` on the very next line | **1** |
| `except` with only comments and blank lines before `end` | **11** |
| `except` whose next token is not `on ... do` - **correct** | **102** |

The first two are not "nearly right". They find one hundredth and one tenth of the truth, and the ninety-one they miss are ordinary working code. The skill's own worked example in rule 10 - the `EXCEPT Inc(Result); END;` in `C:\Projects\LightSaber\LightCore.IO.pas` line 2071 - is one of the ninety-one.

**Before it can count anything, the script must know which characters are code.** This is the whole difficulty, and getting it wrong produced every mistake this skill has ever made. Delphi has four things that look like code and are not: `{ }` and `(* *)` comments, both of which span lines; `//` to the end of a line; and `'...'` string literals. A search that reads them as code:

- **reports a block that has a handler as a bare catch**, when a `{ }` comment sits between the `except` and its `on ... do`;
- **reports a commented-out block as live code**;
- **calls a swallowing block correct**, when the word `raise` appears in a comment or a string. Two real LightSaber blocks do exactly this. `C:\Projects\LightSaber\FrameVCL\LightVcl.Visual.AppData.pas` line 300 and `C:\Projects\LightSaber\FrameFMX\LightFmx.Common.AppData.pas` line 194 are blind catches that only log, and the comment explaining them contains the words *"an unguarded raise here would skip all of that"*. A word-search for `raise` files both under "correct, clear it" - the one pile nobody opens. That is worse than a false alarm: a false alarm is visible and a reader corrects it, while this deletes a real finding from the report.

So the scanner blanks comments and string literals **first** - replacing them with spaces and keeping every newline, so line numbers never move - and only then reads the source. It then walks tokens rather than lines, so a nested `begin`/`end` never ends a body early and no line cap ever truncates one. Finally it sorts every hit into six piles, because "does the body contain the word `raise`" is not the same question as "does the body end in a bare `raise;`".

**The scanner is a file in this skill's own folder. Do not retype it and do not edit it to run it** - it takes the scope and the exclusions on the command line:

```powershell
python "c:\Users\<you>\.claude\skills\light-review-DelphiExceptions\scripts\find-bare-catches.py" `
       "c:\Projects\LightSaber" `
       --exclude UnitTesting --exclude Demo --exclude External `
       --report "c:\AI\Claude Code\Temp\bare-catches.txt"
```

`--exclude` takes a folder NAME and is repeated once per folder. `--report` also writes the output to a file; without it the report only goes to the screen. `--all` additionally lists the two cleared piles, which you want only when somebody disputes a clearance.

**Use the same exclusion list here as in searches 1 and 2, and write it into the report.** Nothing enforces that, and a total built from two different folder lists is meaningless - which has already happened once in this skill.

**If you change the scanner, run its test first.** `scripts/test-find-bare-catches.py` checks the scanner against seventeen blocks whose true answer is written on the `except` line itself. It must print `All green.` Every fault this scanner has ever had was invisible to reading and invisible in its own output - two earlier versions reproduced their totals exactly while getting entries wrong inside them.

```powershell
python "c:\Users\<you>\.claude\skills\light-review-DelphiExceptions\scripts\test-find-bare-catches.py"
```


Read the output this way. Two piles are cleared without reading; the other four all need a verdict. Counts are LightSaber on 2026-09-05, out of 102 bare catches:

- **`RERAISES` (42)** - the body holds an unconditional bare `raise;`. The block frees what it owns and lets the exception out. Correct. Clear it.
- **`madExcept` (0)** - the body calls `HandleException` **and** the unit really references madExcept, so the program keeps running *and* the report is mailed (rule 7). Correct. Clear it.
- **`CONDITIONAL` (1)** - there is a bare `raise;`, but an `if` sits in the same body, so the block re-raises only sometimes and swallows the rest of the time. Needs a verdict. LightSaber's one case is `C:\Projects\LightSaber\FrameVCL\LightVcl.Graph.Loader.Thread.pas` line 224, whose body is `FreeAndNil(BMP); if NOT SilentErrors then RAISE;` - with `SilentErrors` TRUE it swallows, and `SilentErrors` is a public field any caller can set.
- **`WRAPPED` (0)** - the body raises something new (`raise EMyError.Create(...)`) instead of re-raising. The original exception and its stack are thrown away, which is rule 3's fault in its worst form. Needs a verdict.
- **`NO-MADEXCEPT` (1)** - the body calls something named `HandleException`, but the unit never mentions madExcept, so it is a routine of your own with a confusing name. LightSaber's one case is `LightVcl.Graph.Loader.Thread.pas` line 184: `Handleexception` there is the thread class's own virtual method (declared line 76), which shows a message box and swallows. Needs a verdict.
- **`SWALLOWS` (58)** - the exception stops here. Every one needs a verdict.

**Two ways this search has been written wrong before. Both produced output that looked entirely plausible.**

**Never look forward with an array index in a streaming tool.** The first version was `awk` that buffered lines into `buf[FNR]` and then read `buf[xl+1]` to see what came after the `except`. Awk has not read those lines yet - it is a one-line-at-a-time tool - so `buf[xl+1]` held a leftover line from the *previous file*. It reported 100 swallows where there were 61, and called 35 correct `raise;` blocks silent. Nothing warned. Any classification that needs to see what comes *after* a match must read the whole file first.

**Never search source text for a keyword before you have removed the comments and the strings.** The second version cleaned comments with `re.sub(r'\{[^}]*\}', '', s)`, one line at a time. A `{ }` comment that spans lines survives that, so its first line was read as code and its words were searched. Five of the 107 entries it produced on LightSaber were wrong: two blocks that have an `on ... do` handler behind a comment were reported as bare catches, one commented-out block was reported as live, and two blind catches were filed under "correct, clear it" because their explanatory comment contains the word *raise*.

**And test the script against blocks whose answer you already know before you trust one number of its output.** Both wrong versions reproduced their own totals exactly, on two days, in two sessions. A count that reproduces says nothing about the entries behind it.

**Search 4 - the `else` catch-all, which reads as NARROW and is not.** This one does span lines, so use the **Grep tool** with `multiline: true`, `-i: true`, `glob: *.pas` and `path` set to the scope folder. Delphi allows an `else` part after the `on ... do` handlers, and that `else` catches everything the named handlers did not. Search 2 never finds it, because there is no `on E: Exception do` anywhere in the block:

```
pattern: \bon\b[^\n]*\bdo\b[^\n]*\n(?:[^\n]*\n){0,12}?[ \t]*else\b
```

On LightSaber this gives 8 hits in 4 files - small enough to check every one by eye, which you must, because an ordinary `if..else` written just below an `except` block matches it too. What you are looking at is the body of the `else`:

- `else RAISE;` is the correct idiom and is **not** a finding. Every named class is handled, everything else goes on to madExcept. Real code: `C:\Projects\LightSaber\FrameVCL\LightVcl.Common.Shell.pas` lines 301-307, 343-349 and 397-399.
- `else` with any other body is a blind catch wearing narrow handlers. Verdict BLIND, and say in the finding that the `else`, not the `on` handlers, is what does the damage.

**Why `-i` is not optional.** Delphi ignores letter case, and the house style in these projects writes keywords in capitals - `TRY`, `EXCEPT`, `ON E: Exception DO`, `RAISE`. Every code sample further down this file is written that way. A lower-case-only search finds none of them and reports no error. Measured on `C:\Projects\LightSaber\`: searching for `except` in lower case only finds 63 files where 97 contain one, because 156 occurrences of `EXCEPT` in capitals are invisible to it (measured 2026-09-05). A file written entirely in capitals is then reported as having no try..except block at all.

**Why search 2 allows any variable name, or none.** All three spellings below are legal Delphi and all three are blind catches. A pattern that hard-codes the single letter `E` followed by a colon finds only the first:

- `on E: Exception do` - the common spelling
- `on E2: Exception do` - the handler variable may be any identifier. Real case: `C:\Projects\LightSaber\FrameFMX\LightFmx.Common.Graph.pas` line 187
- `on Exception do` - no variable at all, which is valid. Real case: `C:\Projects\LightSaber\External\Exif\CCR.Exif.TiffUtils.pas` line 321

On LightSaber (2026-09-05) the broad pattern above finds 91 and the narrow `on E: Exception do` finds 89. The two it adds are `C:\Projects\LightSaber\External\Exif\CCR.Exif.TiffUtils.pas` line 321 (`on Exception do`, no variable) and `C:\Projects\LightSaber\FrameFMX\LightFmx.Common.Graph.pas` line 187 (`on E2: Exception do`). Two matches out of 91 is a small gain - **the `-i` flag is the one that matters here**, since without it the same broad pattern finds only 70.

**Search 5 - the handler that crashes while handling.** A handler that raises while handling an exception is worse than the block it sits in. The usual cause is a global that shutdown has already set to NIL. Use the Grep tool, `multiline: true`, `-i: true`, `glob: *.pas`:

```
pattern: \bexcept\b[\s\S]{0,400}?\bAppDataCore\s*\.\s*(RamLog|IniFile)\b
```

**Name the instance members, not the global.** This is the whole difficulty of this search, and the earlier version of it got this wrong. In LightSaber, `TAppDataCore.LogError` and its nine sisters (`LogWarn`, `LogInfo`, `LogMsg`, `LogBold`, `LogHint`, `LogImpo`, `LogVerb`, `LogEmptyRow`, `LogClear`) are **`static` class methods that test the global for NIL themselves** - `C:\Projects\LightSaber\LightCore.AppData.pas` line 190, body at 686-689:

```pascal
class procedure TAppDataCore.LogError(CONST Msg: string);
begin
  if AppDataCore <> NIL then AppDataCore.doLogError(Msg);
end;
```

So `AppDataCore.LogError('x')` is safe even when `AppDataCore` is NIL, and a search for the bare `AppDataCore\s*\.` returns 51 of those out of 59 hits - all noise. Only a real **instance** member can raise: `AppDataCore.RamLog`, `AppDataCore.IniFile`. Those are what the pattern above names. Then keep the hits with no `if AppDataCore <> NIL` or `if Assigned(AppDataCore)` in front.

Two things to carry to another project. **First, check whether the routine guards itself before you require a guard at the call site.** One look at its declaration decides it, and requiring a guard the routine already performs is exactly the dead code rule 6 warns about. **Second, the character window is a real limit.** At 300 characters this search missed the one LightSaber handler that genuinely needs the guard: `C:\Projects\LightSaber\FrameVCL\FormSkinsDisk.pas` line 131 calls `AppDataCore.RamLog.AddError(...)` with no NIL test, and a four-line comment between the `except` and the call pushed it out of range. Widen the window rather than trust a clean result.

Print all five counts before you start judging anything.

**Those counts are matches, not blocks - never report them as blocks.** Three ways they differ, all of them seen on LightSaber:

- One block can produce several matches. A block that names three narrow classes and then ends with `on E: Exception do ... RAISE;` matches search 2 once, and that match belongs to a block that is correct.
- One finding can produce many matches. `C:\Projects\LightSaber\FrameVCL\LightVcl.Graph.Loader.pas` gives 24 separate hits from 24 near-identical blocks with the same body and the same `//todo` comment beside each. That is **one** finding with 24 line numbers, not 24 findings - see Step 4.
- Search 1 counts every `except` keyword in the project and is always far larger than the rest: 291 on LightSaber against 91 matches for search 2 (2026-09-05). Never use search 1 to size the job.

Size the job by **the matches from searches 2, 3 and 4 that survive the "What NOT to flag" list**. On LightSaber (2026-09-05) that is 74 blind catches (from 91, once `UnitTesting`, `Demo`, `External` and `_Frozen Streams` are dropped) plus the 58 *swallowing* bare catches from search 3, plus its 1 `CONDITIONAL` and 1 `NO-MADEXCEPT` - **134 blocks**. The other 42 bare catches end in an unconditional bare `raise;`, so they cost nothing to clear.

**Drop the same folders everywhere, or the total is nonsense.** Searches 1 and 2 are written above with no folder filter at all, the script's `SKIP` names three folders, and the scope paragraph at the top of Step 1 names five more. Pick one list for the whole audit, write it down in the report, and use it in every search. The 74 above needs four folders dropped; dropping only the script's three gives 75.

**Above about 60 blocks needing a verdict, work folder by folder and write the report folder by folder.** Do not try to hold the whole project in one answer - the quality of the verdicts falls long before the context runs out. LightSaber is a 134-block project, so LightSaber is audited folder by folder.

**Read the whole procedure around each block, not just the block.** A catch is only judgeable against what the code before it does and what the caller expects after it.

---

## Step 2 - Sort the exception classes

The whole audit turns on one split: **the outside world refused** versus **we wrote a bug**.

### When the class is on neither list, ask who could have prevented it

The two lists below cannot name every class in every library. For anything they miss, use this test, which comes from the Delphi-PRAXiS thread "Best way of handling exceptions" (topic 13321), where Kas Ob. put it this way:

> *"Losing server connection can't be prevented by code or its developer, and that is the difference between error and exception, unlike bad/broken SQL, an error here means the code is missing edge cases or sanitizing the data."*

So: **could a developer have stopped this from happening by writing better code?**

- **No** - a dropped network share, a removable drive pulled out, a virus scanner holding a file, a server that went away. Nothing to fix, nothing to report. Catch it and tell the user in plain words.
- **Yes** - malformed SQL our own code built, an index we never checked, a value we never sanitised. That is a bug. Let it out.

In the same corpus, Anders Melander describes the same rule from the other end, and names madExcept as the destination (thread "Try..except..finally..end;", topic 14613): *"In my applications, unhandled exceptions are allowed to propagate all the way to the top to be caught by madExcept, and presented to the user as a bug report - Because that's what they are: Bugs."* He calls the first category **soft errors** and absorbs them: *"temporary sharing violations, virus scanners getting in the way, network glitches... The stuff that I either didn't anticipate or which must not happen I let propagate."*

A second test, from the same threads, catches what the first one misses - a handler that has no idea what to do: *"I always think in terms of: try A, except plan B. If I don't have a plan B, then it's not the right place to handle it."* A handler with no plan B is not handling anything. It is swallowing.

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

**Never narrow a block to `EArgumentException` itself.** Two of its descendants sit 47 lines apart in the runtime library and have opposite verdicts: `EInOutArgumentException` (line 516) is a bad path the user typed and must be caught, while `EArgumentOutOfRangeException` (line 469) is our own bug and must reach madExcept. Catching the parent swallows both.

Add per project, after checking the declaration yourself: database connection errors and `EPrinter`.

**Indy has its own tree, and there is a usable list.** Every Indy exception descends from `EIdException`, so `on E: EIdException do` is the one-line narrowing that covers all of them. For a `TIdHTTP` call, Remy Lebeau - Indy's own maintainer - named these in the Delphi-PRAXiS thread "Good example of what exceptions TIdHTTP (cielt) can raise" (topic 7279): `EIdHTTPProtocolException`, `EIdUnknownProtocol`, `EIdIOHandlerPropInvalid`, `EIdReadTimeout`, `EIdSocketError`, `EIdInternetPermissionNeeded`, `EIdConnClosedGracefully`, `EIdClosedSocket`, `EIdNotConnected`, `EIdNotASocket`. He also says Indy defines a few hundred exception classes, so no list is ever complete - which is exactly why `EIdException` is the safer narrowing.

**One Indy-only rule that overrides everything else here:** inside an Indy server's own handler you must **re-raise** any `EIdException` you catch, with a bare `raise;`. Remy Lebeau, thread "Indy HTTP server" (topic 5381): *"make sure to RE-RAISE any Indy exceptions you happen to catch (they all derive from EIdException). The server needs to handle those internally in order to close the socket and stop its owning thread."* Swallowing one leaks a socket and hangs a thread.

### Our bug - catching is wrong, let madExcept mail it

These cannot be caused by a locked folder. Every one of them means the code is wrong.

`EAccessViolation` (nil pointer, freed object) - `EInvalidPointer` (double free, corrupt heap) - `EListError` (index past the end of a `TList` or `TStrings`) - `ERangeError` and `EArgumentOutOfRangeException` - `EIntOverflow`, `EDivByZero`, `EZeroDivide` - `EInvalidCast` (a bad `as`) - `EAbstractError` - `EAssertionFailed` - `EStackOverflow` (runaway recursion).

### Neither of the two - must pass straight through, untouched

`EAbort` belongs in no bucket above. It is not a failure at all: it is how the runtime library cancels an operation quietly, and the VCL is built to show nothing for it. Catching it is wrong, but so is reporting it - there is nothing to report. It must simply travel on. Rule 2 further down says how, and why a blind catch turns a user pressing Cancel into an error box saying "Operation aborted".

Do not put `EAbort` in a "not our fault, catch it" handler and do not treat it as a madExcept case.

### Depends on where the value came from

- **`EConvertError`** - `StrToInt` on garbage. If the string came from a user, a file or a web answer, it is bad data and catching is right. If our own code built it, it is our bug.
- **`EOutOfMemory`** - a 32-bit process asked for more than the address space has (a huge image: not our fault), or something leaks (our fault).

---

## Step 3 - Give the block a verdict

**Five verdicts. Test the five numbered rows in the order they are printed and stop at the first that fits.** More than one will often fit - a bare `except` that does nothing is blind and silent at the same time - and without a fixed order two people audit the same block and write down two different verdicts. The two rows numbered `-` are not verdicts; they are notes attached to the row above and below them, and you read them without ever stopping on them.

The five are **JUSTIFIED, SILENT, BLIND, NARROW, UNSURE**. (The skill's own `description:` line names only four of them - it has no room for UNSURE, which is a verdict like any other and must be written into the report whenever it fits.)

| # | Verdict | What it means | Action |
|---|---|---|---|
| 1 | **JUSTIFIED** | Catches broadly on purpose, **and the reason is visible.** Visible means either a comment in the code says why, or the block is one of the cases listed under "What NOT to flag" at the end of this file - a destructor, `OnCloseQuery`, `OnClose`, `OnDestroy`, a `finalization` section, a `stdcall` callback the Windows API calls back into, a DLL export, a COM method, a blind catch that logs and then re-raises with a bare `raise;`, **or a blind catch that calls `madExcept.HandleException` (rule 7)** - the program keeps running *and* the report is mailed, so nothing is hidden. In those places the context is the reason and no comment is required. **One exception, and it is row 2's:** a block cleared here only because its routine has a documented "never raises" contract is NOT finished - see the third paragraph under this table. | **The catch is cleared. The handler body is not.** Read what is inside it before you move on - see below. Then say in the report that you cleared it, and why. |
| 2 | **SILENT** | Catches broadly **and does nothing at all** - no log, no message, no re-raise, no error value handed back to the caller. The worst kind: the program keeps running in a state nobody understands and nobody ever learns why. | Always a finding. |
| - | *(border case, read this before using row 2)* | `EXCEPT Result:= FALSE; END;` and `EXCEPT Result:= 'Unknown'; END;` are **not** SILENT. Returning `FALSE`, `-1` or a placeholder string *is* an error value handed to the caller, so they are row 3, BLIND. The distinction is thin but it matters: the caller can at least see that something went wrong. What it cannot see is **what** went wrong, so say that in the finding. **A counter handed back from inside a loop** - `EXCEPT Inc(Result); END;` - is the same case and is also BLIND, not SILENT, even though rule 10 lists everything else wrong with it. Rule 10 tells you what to write in the finding; this row decides the verdict. | Row 3. |
| - | *(and the one that looks like it but is fine)* | `EXCEPT FreeAndNil(Result); RAISE; END;` is **correct and not a finding** - the half-built object is cleaned up and the exception still travels on to madExcept. On LightSaber this shape appears 36 times (2026-09-05) and every one of them has the `raise;`. Check for it before you write the finding: without the `raise` it is BLIND, with it there is nothing to do. | None. |
| 3 | **BLIND** | Catches broadly and does do something, but the something is not enough to stop our own bugs from disappearing. Covers `on E: Exception do`, a bare `except`, and an `else` part whose body is not `RAISE;`. | Rewrite: name the classes that can really happen here - see "How to find those classes" below. |
| 4 | **NARROW** | Names only classes from the "not our fault" list of Step 2 - **or only classes from the "depends where the value came from" list, where you traced the value and it came from outside the program.** Our own bugs still fly out to madExcept either way. | Nothing. This is the target shape. A narrow block that swallows without a log is still worth one line in the report - but it is not SILENT, because madExcept keeps getting our bugs. Real case: `C:\Projects\LightSaber\FrameVCL\LightVcl.Common.IO.pas` lines 779-781 catch only `EConvertError` around a timestamp read from the file system. `EConvertError` is a "depends" class, the value comes from outside, so the verdict is NARROW - not UNSURE, because the question *was* answerable. |
| 5 | **UNSURE** | You could not answer some question the verdict depends on - which classes the called routine can raise, where a value came from, whether a thread can reach this line. | Put it in the report as UNSURE **with the question you could not answer**. Never drop it silently and never guess a verdict. |

### Three things the verdict alone will get wrong

**JUSTIFIED clears the catch, never the handler body.** A handler runs at the worst moment the program will ever have - something has just failed. Code that is safe anywhere else is not safe in there. After clearing a block, read the handler body and ask whether it can itself raise. Real case, and the trap inside the trap: `C:\Projects\LightSaber\ciUpdater.pas` line 196 is a blind catch in a **destructor**, which rule 1 blesses without argument - and its one line is `AppDataCore.LogError('Updater.Save failed: ' + E.Message)` with no NIL check. A destructor runs at shutdown, which is the exact moment `AppDataCore` is set to NIL. That reads like a certain access violation while handling an exception. **It is not, and the reason is the point of this paragraph.** `TAppDataCore.LogError` is a `static` class method that tests the global itself (`C:\Projects\LightSaber\LightCore.AppData.pas` line 190, body at 686-689: `if AppDataCore <> NIL then AppDataCore.doLogError(Msg);`), so the call is safe. An **instance** member in the same position - `AppDataCore.RamLog.AddError(...)`, `AppDataCore.IniFile` - would have raised. So: read the handler body, and then read the declaration of what it calls. The shape of the call tells you nothing.

**The reason for a silent catch is often written above the `try`, not inside the `except`.** Before writing SILENT, read the whole procedure and the comment block above it. Real case: `C:\Projects\LightSaber\FrameFMX\LightFmx.Common.CrashHandler.pas` lines 179-180 are `EXCEPT` with `END;` on the next line and nothing in between - and the four lines at 172-175, directly above the `TRY` at 176, explain that the block runs on a later message-loop turn where a raise would start a repeating error storm. (Line numbers measured 2026-09-05; this file has moved three times in two days, so find the block by its comment, not by its line.) Flagging it SILENT would be a false alarm and would cost the reader's trust in every other line of the report.

**A documented "does not raise" contract is a promise to the caller, not a licence to swallow our bugs.** The "What NOT to flag" list clears a function whose comment says it returns an error value and never raises. Read that narrowly: it clears the *decision to catch*, not the decision to catch `Exception`. The contract can be kept and our bugs still reported - name the classes the outside world can cause, and put `madExcept.HandleException` (rule 7) in the catch-all so the crash is mailed while the function still returns its error string.

### How to find those classes, for a BLIND block

This is the hard half of the job and the table above cannot do it for you. Work outwards:

1. **List what the `try` block actually calls.** Every routine, every property setter, every `as` cast, every array index.
2. **For each call, find its declaration and read it.** The declaration tells you the truth; the name does not. A routine called `SaveX` may raise nothing at all - see rule 8, where three folder-creating routines behave three different ways.
3. **Keep only what the outside world can cause.** Match against the two lists in Step 2. An `EAccessViolation` from that list is never a class you name - it is the whole reason the block is being narrowed.
4. **If a call raises nothing** (it returns `False` instead), the `try..except` was never protecting it. Say so, and test the result instead - rule 8.
5. **If you cannot get to the declaration** - a third-party unit with no source, a virtual method with many overrides - the verdict is UNSURE, not a guess.

### Order the handlers: most specific first

Delphi runs the `on` handlers top to bottom and stops at the first class the exception belongs to. So an ancestor placed above its own descendant makes the descendant unreachable, and the code silently does the wrong thing.

Concretely, from Step 2: `EStreamError` is the ancestor of `EFCreateError` and `EFOpenError`. Written in this order, the second and third handlers can never run:

```pascal
EXCEPT
  ON E: EStreamError   DO ...   { swallows both of the two below }
  ON E: EFCreateError  DO ...   { dead }
  ON E: EFOpenError    DO ...   { dead }
END;
```

Two consequences worth writing into a finding:

- If the handlers do the same thing, name only the ancestor and drop the descendants.
- If they do different things, put the descendants **above** the ancestor.
- `ON E: EAbort DO RAISE;` from rule 2 must be the **first** handler in the block, above everything, because `EAbort` descends from `Exception` and any broad handler above it would eat the user's cancel.

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

## The eleven rules

The argument and the evidence for each rule live in **`references/the-eleven-rules.md`** (in this skill's folder). Read that file when a block touches one of these - not before, and not all of it:

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

Rules 1, 2 and 10 decide verdicts and come up in almost every audit. Rules 3 to 9 and 11 are Delphi and LightSaber specifics you look up when a block calls the routine in question.

## Step 4 - Report

Write the findings to `ExceptionAudit <YYYY-MM-DD>.md`. Where that file goes:

- Scope is a folder → in the project root, meaning the folder that holds the `.dproj` or `.dpr`. If the scope folder has none above it, write it in the scope folder itself.
- Scope is a single file → beside that file.
- Report written folder by folder → still **one** file, appended to as you go, not one per folder.

Change no code unless `$args` contains `fix`.

Summary table first, one row per finding, worst first:

| # | File : line | Procedure | Verdict | Why | Fix |
|---|---|---|---|---|---|
| 1 | `BxParallaxEditor.pas:1207` | `btnSaveClick` | BLIND | `on E: Exception` also eats an access violation from `FLayers[]`; madExcept never mails it | Narrow to `EStreamError`, `EInOutError`, `EOSError` |

**One row per FINDING, not one row per match.** Blocks that share a body, a cause and a fix are one finding with a list of line numbers in the first column. This is not a saving of space, it is the difference between a report somebody acts on and a report nobody reads: on LightSaber, `FrameVCL\LightVcl.Graph.Loader.pas` alone produced 24 matches with the same three-line body and the same `//todo` comment, and 9 more came from one `ReadHeader` routine copy-pasted into three stream units. Written out flat that is 33 of 74 rows saying the same sentence, and the eight findings that actually differ disappear underneath them.

Group when all three are true: same shape of handler, same reason it is wrong, same fix. Otherwise keep them apart.

**One block can hold two findings.** Judge the catch and the handler body separately - a blind catch whose handler can itself raise is two lines in the table, not one, because the two are fixed in different places by different edits. **The handler body is a finding only when it can really raise**, which means an unguarded *instance* member of a global (`AppDataCore.RamLog.AddError(...)`), never a self-guarding static call (`AppDataCore.LogError(...)`) - see rule 6. Log-then-re-raise, the pattern shown under rule 3, is one finding at most and usually none.

Then one short block per finding: the code as it stands, and the code as it should read. For a grouped finding show **one** pair of code blocks, from the first line number listed.

End the file with this line, exactly:

> Audit produced by <model name>. Counter-analysis must run in a NEW session - re-open this file there and ask for the line of code that proves or disproves each finding.

**Why a new session:** re-checking findings in the session that produced them is measured as the worst of the four ways tested - 21.7% against 28.6% for a fresh session, and the most false alarms, 4.4 per document against 3.1 (Song, arXiv:2603.12123). Do not counter-analyze your own report here, and do not spawn a subagent to do it - a subagent checking the parent scored 23.8%, no better than not separating at all.

## What NOT to flag

- `try..finally`. It does not catch.
- A blind catch in `OnCloseQuery`, `OnClose`, `OnDestroy`, a destructor or a `finalization` section - rule 1 says that is correct.
- A blind catch that logs and then re-raises with a bare `raise;` - madExcept still gets it, with the right stack.
- A blind catch at a boundary an exception must not cross, where it must become a return code instead: a `stdcall` callback the Windows API calls back into, a DLL export, a COM method, and the same thing on mobile - an anonymous method handed to the Android or iOS platform layer, which calls it back from code that is not Delphi.

  **Check for this boundary before you judge a single block in a unit, not after.** It is one command and it decides the verdict of every block in the file at once: `grep -c "stdcall;\|cdecl;" "<the unit>"`. A count above zero means the unit is an export layer and its blind catches are correct by design. Real case: `C:\Projects\LightSaber\HardwareID\chHardID_C.pas` has 35 of them and ships as `HardwareIDExtractorC.dll`; its 17 bare catches all read `EXCEPT Result:= nil; END;` and every one is right, because an exception must not cross into C. The sister unit `chHardID.pas` has **zero** `stdcall` - it is the implementation, not the boundary - and its eleven near-identical-looking catches *are* findings. Same folder, same shape, opposite verdicts, and the only thing that separates them is that one grep.
- A function whose documented contract is to return an error string and never raise. **Read this narrowly.** It clears the decision to catch, not the decision to catch `Exception` - see "Three things the verdict alone will get wrong" in Step 3.
- An `else` part whose body is `RAISE;`. Everything the named handlers did not take goes on to madExcept, which is the whole point.
- Test code, demo projects, and third-party source.

Report a count of the blocks you looked at and cleared, so the numbers add up, and list the cleared ones with the reason each was cleared - a report that shows only findings cannot be checked by anybody. A block you were unsure about goes into the report marked UNSURE, with the question you could not answer - never silently dropped.

**Say plainly when a whole verdict came back empty.** "No SILENT block in this project" is a real result and the reader wants it. A report that lists only what is wrong leaves them unable to tell a clean project from an unfinished audit.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
