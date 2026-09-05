# Delphi vocabulary — banned and preferred terms

Last updated: 2026-08-09.

Loaded by the `light-md-DelphiIdiom` skill. Sections:

- **A. Hard bans** — clean 1-to-1 replacement, safe to auto-apply.
- **B. Context-dependent** — flagged with surrounding context, human decides.
- **C. Already Delphi-correct** — use freely; do NOT over-correct.
- **D. Open questions** — unresolved; resolved through Q&A and migrated to A or B.
- **Allowlist** — phrases that LOOK like banned terms but are legitimate Delphi/industry uses.

Edit this file when a new term is decided. Source citations are in the **Sources** section at the bottom.

---

## Section A — Hard bans (auto-replace)

Match these case-insensitively as whole words (or whole phrases for multi-word entries). Apply the replacement directly. Skip matches inside fenced code blocks, inline backticks, URLs, and any phrase listed in the **Allowlist** at the bottom.

| Bad term                  | Replacement                        |
| ------------------------- | ---------------------------------- |
| null                      | nil                                |
| NULL                      | nil                                |
| enum                      | enumeration                        |
| struct                    | record                             |
| reflection                | RTTI                               |
| header file               | interface section                  |
| header files              | interface sections                 |
| lambda                    | anonymous method                   |
| lambdas                   | anonymous methods                  |
| try/catch                 | try/except                         |
| try-catch                 | try..except                        |
| lint                      | compiler hint                      |
| linter                    | compiler hints/warnings            |
| linting                   | running compiler hints/warnings    |
| destructor chain          | destructor                         |
| null pointer              | nil reference                      |
| array index out of bounds | range check error                  |
| compile-time constant     | typed constant                     |
| module                    | unit                               |
| modules                   | units                              |
| dynamic library           | DLL                                |
| shared library            | DLL or BPL package                 |
| pure virtual              | abstract                           |
| closure                   | anonymous method                   |
| returns void              | returns nothing (procedure)        |
| void function             | procedure                          |
| void return type          | procedure (no return)              |
| C/C++ header              | interface section                  |
| .h header                 | interface section                  |
| stub out                  | not wired up                       |
| stubs out                 | does not wire up                   |
| stubbed out               | not wired up                       |
| scaffold                  | skeleton                           |
| scaffolds                 | skeletons                          |
| scaffolding               | skeleton code                      |
| boilerplate               | repeated setup code                |
| test double               | fake implementation                |
| test doubles              | fake implementations               |
| code smell                | warning sign                       |
| code smells               | warning signs                      |

**Auto-fix exclusions (in addition to the universal code-block / backtick / URL skips):**

- Words that are part of compound proper names (`ToolsAPI`, `Windows API`, `Claude API` — Section B).
- Phrases in the **Allowlist** below.

---

## Section B — Context-dependent (flag, do not auto-fix)

Report these with file:line and a snippet (full line or ~60 chars) so a human can decide.

| Term                                            | OK when                                                                             | NOT OK when                                                                                                                           |
| ----------------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| API                                             | Windows API, ToolsAPI, Claude API, Anthropic API, REST API, named published service | a unit's exported procedures — say "interface section" or "exported routines"                                                         |
| interface                                       | the `interface` keyword (COM-style contract)                                        | a unit's interface section — say "interface section"                                                                                  |
| method                                          | class member procedure/function                                                     | a standalone routine — say "procedure" or "function"                                                                                  |
| object                                          | instance of a class                                                                 | the legacy `object` keyword — say "old-style object"                                                                                  |
| library                                         | DLL or BPL package                                                                  | ambiguous Delphi `library` keyword — say which                                                                                        |
| protocol                                        | network protocol (HTTP, JSON-RPC)                                                   | Delphi interface — say "interface"                                                                                                    |
| schema                                          | JSON schema, DB schema                                                              | Delphi record structure — say "record"                                                                                                |
| component                                       | TComponent descendant                                                               | generic piece of code — say "unit" or "class"                                                                                         |
| handler                                         | "event handler" full phrase                                                         | bare "handler" — keep "event handler" full                                                                                            |
| callback, callback function, callback procedure | when context is clear from surrounding text                                         | flag — could mean event handler (TNotifyEvent), anonymous method (reference-to-procedure), or procedure variable. Pick the right one. |
| namespace                                       | unit namespace, dotted unit name (`System.Classes`)                                 | generic — say "unit scope"                                                                                                            |
| static (modifier)                               | `class procedure ... static;` (the Delphi keyword)                                  | C-style "static variable" — say "global variable"                                                                                     |
| void                                            | the English word ("void warranty", "fill the void")                                 | C/C++ return type — say "procedure"                                                                                                   |
| import                                          | importing data into an app (UI sense)                                               | source-code use — say "uses clause"                                                                                                   |
| throw                                           | English idiom ("throw an error message")                                            | exception-raising verb — say "raise"                                                                                                  |
| true (lowercase)                                | English sentences ("true if X", "true positive")                                    | Delphi boolean literal — say `TRUE`                                                                                                   |
| false (lowercase)                               | English sentences ("false positive")                                                | Delphi boolean literal — say `FALSE`                                                                                                  |
| function signature                              | reading a `function` declaration                                                    | covering procedures/methods generically — say "routine signature"                                                                     |
| header                                          | `## Markdown header`, HTTP header, table header                                     | C/C++ `.h` file sense — say "interface section"                                                                                       |
| method overloading                              | when "method" is specifically a class member                                        | covering procedures generally — say "overloaded procedure"                                                                            |
| garbage collector                               | n/a                                                                                 | Delphi has no GC. Flag and rephrase.                                                                                                  |
| garbage collection                              | n/a                                                                                 | Same — flag and rephrase.                                                                                                             |
| GC                                              | n/a                                                                                 | Same — flag and rephrase.                                                                                                             |
| header guards                                   | n/a                                                                                 | N/A in Delphi (units cannot be double-included). Flag and rephrase.                                                                   |
| include guards                                  | n/a                                                                                 | Same — flag and rephrase.                                                                                                             |
| mutex                                           | OS-wide named lock — `System.SyncObjs.TMutex` exists                                | in-process locking — say `TCriticalSection` or `TMonitor`                                                                             |
| stack trace                                     | `Exception.StackTrace` property; madExcept output; JclDebug output                  | the IDE's Call Stack debugger window — say "Call Stack"                                                                               |
| static analysis                                 | external tools (FixInsight, SonarDelphi, Peganza Pascal Analyzer, DerScanner)       | Delphi's own compiler messages — say "compiler hints/warnings"                                                                        |
| wire, wires, wiring, wires up, wired up         | network/electrical wiring; wire format/protocol                                     | JS-framework vocabulary for event assignment — say "`.OnX := YHandler`" or "assigns Y to OnX" or "registers Y as OnX"                 |
| surface, rendering surface                      | FMX `TCanvas` drawing target; OS abstraction layer (the "Windows API surface")      | borrowed graphics-framework metaphor for "feature" or "subsystem" — say "viewer", "control", "unit", or name the actual class         |
| shim, shims                                     | a thin compatibility wrapper around an OS/COM API (rare, but legitimate)            | borrowed JS-framework vocabulary for placeholder code — say "stub", "wrapper", or name the unit                                       |
| hook into, hooks into                           | Win32 `SetWindowsHookEx`, message-hook chains, IDE OTA notifiers (`ToolsAPI`)       | borrowed event-system vocabulary — say "assigns to" / "subscribes to" / "registers with"                                              |
| seam, seams                                     | a literal seam — fabric / weld / geology — or quoted from a source                   | borrowed testing/refactoring jargon for a substitution point — say "an interface used for dependency injection", "a substitution point", or name the actual boundary/unit |
| tracer bullet                                   | kept where the doc defines it (e.g. `light-new-Feature` defines slice 1 this way) | borrowed Pragmatic-Programmer metaphor used without a definition nearby — say "a thin end-to-end first slice"                          |
| headless, headless mode                         | a real headless *machine* — a server or a build box with no monitor attached, where the word is literal | borrowed sysadmin word standing in for "shows no window". Say what is actually suppressed: "shows no exception box", "no-box settings", "no GUI". If the point is that nobody is watching, say **unattended**. If the program genuinely has no GUI at all, say **console application** (`{$APPTYPE CONSOLE}`) |

---

## Section C — Already Delphi-correct (no action)

These look foreign but are actually standard Delphi vocabulary. Do not flag, do not replace.

**Core OO + types:**
property, field, event, event handler, method (on a class), procedure, function, class, record, set, array, dynamic array, enumeration, generic, generic type, generic method, parameterized method.

**Unit structure:**
unit, uses clause, interface section, implementation section, initialization section, finalization section, package, BPL, DLL.

**RTTI + introspection:**
RTTI, attribute, reference counting, TInterfacedObject.

**Exceptions + flow:**
exception, raise, try..except, try..finally.

**Inheritance + polymorphism:**
virtual, dynamic, override, overload, reintroduce, abstract, sealed, class helper, record helper.

**Closures + procedural types:**
anonymous method, nested procedure, procedural type, method pointer.

**I/O + IPC:**
stream, named pipe, dispatch, predicate, comparer, serialization, binary serialization.

**Error conditions:**
range check, integer overflow.

**Lifecycle:**
finalization, initialization.

**Ecosystem:**
RTL, VCL, FMX, FireMonkey, BPG, DPK, DPR, DFM, FMX file, DCU, BPI, DCP, INI, FastMM, madExcept.

---

## Allowlist — compound phrases that LOOK banned but aren't

The auto-fixer must skip a Section A match when the surrounding text matches any of these patterns. Match the whole phrase, case-insensitive.

| Phrase                   | Reason                                                  |
| ------------------------ | ------------------------------------------------------- |
| submodule                | git term, not "module" in the Delphi sense              |
| data module              | Delphi `TDataModule` — correct                          |
| web module               | Delphi WebBroker module type                            |
| module pricing           | product-feature wording (e.g. TestComplete Modules)     |
| module-bundled           | product-feature wording                                 |
| set-of-enum              | accepted Delphi shorthand for `tkSet` of enumeration    |
| enum/set                 | accepted Delphi shorthand pairing                       |
| set-of-enumeration       | same as set-of-enum, fully spelled                      |
| set of enumerated values | same idea, prose form                                   |
| Web/Mobile module        | TestComplete product-module wording                     |
| Anthropic API            | named published service                                 |
| Claude API               | named published service                                 |
| Windows API              | named platform surface                                  |
| ToolsAPI                 | Embarcadero unit name                                   |
| REST API                 | named architectural style                               |
| Computer Use API         | Anthropic product name                                  |
| HTTP header              | standard web term                                       |
| Authorization header     | standard web term                                       |
| accept header            | standard web term                                       |
| markdown header          | document structure term                                 |
| Web module module        | (placeholder — extend when new false-positive surfaces) |
| Windows API surface      | named platform surface (OS abstraction)                 |
| rendering surface        | legitimate FMX `TCanvas` concept                        |
| drawing surface          | legitimate FMX `TCanvas` concept                        |
| attack surface           | standard security term                                  |
| canvas surface           | legitimate FMX `TCanvas` concept                        |

When the skill finds a Section A match and the surrounding text matches an allowlist phrase, log it as "skipped (allowlist)" rather than fixing or flagging.

---

## Section D — Open questions (unresolved)

Park new vocabulary questions here when the right ruling (ban / context-dependent / already-correct) is not yet decided. When one is resolved, move it into Section A, B, or C and delete it from here (see SKILL.md → "Extending the dictionary").

*(empty — nothing pending)*


