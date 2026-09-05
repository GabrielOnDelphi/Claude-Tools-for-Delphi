---
name: light-review-DelphiExceptions
description: Audit every try..except in a Delphi project and judge each one - does it hide OUR bug from madExcept, or correctly absorb an environment failure (locked folder, full disk, dropped share)? Gives each block a verdict (JUSTIFIED / SILENT / BLIND / NARROW / UNSURE) plus the exact exception classes to narrow it to. Say "check the try/except blocks", "audit exception handling", "are we swallowing exceptions", "why did madExcept never report this".
---

# /light-review-DelphiExceptions - try..except Auditor

Every `except` block gets one question:

> **If this code failed because of a bug of ours, would we ever find out?**

A block that catches `Exception` catches our own access violations too. madExcept then never sees them, never mails a report, and the bug lives forever in every copy the users run. The opposite mistake costs just as much: letting a read-only folder crash the program and fill the mailbox with reports about a problem that is not ours to fix.

Both mistakes come from the same habit - writing `on E: Exception do` because it is shorter than naming the classes that can actually happen.

**Scope:** `except` blocks. `try..finally` never catches anything, so it is out of scope. Unit-test code is out of scope.

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

So the script below blanks comments and string literals **first**, replacing them with spaces and keeping every newline, so line numbers never move. Everything after that reads only code. **Write it to `c:\AI\Claude Code\Temp\find-bare-catches.py`, set `ROOT` to your scope folder, and run it with `python`.** It sorts every hit into six piles, because "does the body contain the word raise" is not the same question as "does the body end in a bare `raise;`":

```python
import io, os, re, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ROOT = r'c:\Projects\YourProject'
SKIP = ('UnitTesting', 'Demo', 'External')          # folders to leave out

def blank(text):
    """Replace every comment and every string literal with spaces, keeping the length
       and every newline, so line numbers never move. Delphi has four of them:
       { } and (* *) span lines, // runs to the end of the line, '...' never spans one."""
    out, i, n, state = list(text), 0, len(text), 0   # 0 code  1 {}  2 (**)  3 '..'  4 //
    while i < n:
        c = text[i]
        if state == 0:
            if   c == '{':                              state = 1; out[i] = ' '
            elif c == '(' and text[i+1:i+2] == '*':     state = 2; out[i] = out[i+1] = ' '; i += 1
            elif c == "'":                              state = 3; out[i] = ' '
            elif c == '/' and text[i+1:i+2] == '/':     state = 4; out[i] = out[i+1] = ' '; i += 1
        elif state == 1:
            out[i] = '\n' if c == '\n' else ' '
            if c == '}': state = 0
        elif state == 2:
            out[i] = '\n' if c == '\n' else ' '
            if c == '*' and text[i+1:i+2] == ')':       out[i+1] = ' '; i += 1; state = 0
        else:                                            # 3 and 4 both end at the line end
            out[i] = '\n' if c == '\n' else ' '
            if c == '\n' or (state == 3 and c == "'"):  state = 0
        i += 1
    return ''.join(out)

WORD  = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
OPENS = ('begin', 'case', 'try', 'asm')

def body_of(src, pos):
    """From just after an EXCEPT keyword, return (body text, position of its own END).
       Counts begin/case/try/asm up and end down, so a nested block never ends the search
       and there is no line cap to truncate a long handler."""
    depth = 0
    for m in WORD.finditer(src, pos):
        w = m.group(0).lower()
        if w in OPENS:
            depth += 1
        elif w == 'end':
            if depth == 0:
                return src[pos:m.start()], m.start()
            depth -= 1
    return src[pos:], len(src)

files = []
for root, dirs, fns in os.walk(ROOT):
    dirs[:] = [d for d in dirs if d not in SKIP]
    files += [os.path.join(root, f) for f in fns if f.lower().endswith('.pas')]

PILES = ('RERAISES', 'madExcept', 'CONDITIONAL', 'WRAPPED', 'SWALLOWS', 'NO-MADEXCEPT')
res = {k: [] for k in PILES}
for f in files:
    raw = io.open(f, encoding='utf-8', errors='replace').read()
    src = blank(raw)                                 # comments and strings gone, line numbers intact
    rel = os.path.relpath(f, ROOT)
    uses_madexcept = re.search(r'\bmadExcept\b', src, re.I) is not None
    for m in re.finditer(r'\bexcept\b', src, re.I):
        if re.match(r'\s*\bon\b[\s(]', src[m.end():], re.I):
            continue                                 # it has a handler: not a bare catch
        b, _ = body_of(src, m.end())
        b = ' '.join(b.split())
        line = src.count('\n', 0, m.start()) + 1
        bare_raise = re.search(r'\braise\s*;', b, re.I) is not None
        any_raise  = re.search(r'\braise\b',   b, re.I) is not None
        if   bare_raise and re.search(r'\bif\b', b, re.I): kind = 'CONDITIONAL'
        elif bare_raise:                                   kind = 'RERAISES'
        elif any_raise:                                    kind = 'WRAPPED'
        elif re.search(r'\bhandleexception\b', b, re.I):   kind = 'madExcept' if uses_madexcept else 'NO-MADEXCEPT'
        else:                                              kind = 'SWALLOWS'
        res[kind].append((rel, line, b[:95]))

for k in PILES:
    print('### %-12s : %d' % (k, len(res[k])))
print('TOTAL bare catches: %d' % sum(len(v) for v in res.values()))
for k in ('CONDITIONAL', 'WRAPPED', 'NO-MADEXCEPT', 'SWALLOWS'):
    for f, l, b in sorted(res[k]):
        print('%-12s %-52s:%-5d %s' % (k, f, l, b))
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
