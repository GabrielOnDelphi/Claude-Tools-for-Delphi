# How to write good MD files for Delphi projects

This file teaches the AI (Claude Code, etc) to write clear, Delphi-correct Markdown documentation — and to fix existing MD files that aren't.

Last updated: 2026-05-21.

---

## Who reads this file

Two consumers, same rules:

- **Write-time:** before writing or editing any MD file in a Delphi project, read this file, then proceed. Print `--!SLIM MD!--` in the final summary so the user knows you read it.
- **Fix-time:** the `/light-md` skill loads this file alongside `vocabulary.md` to retrofit existing MD files. Only for legacy docs.

Same content, two postures: don't write bad MD then fix it later - write it correctly first time.  

---

## The high-bar rule (for edits — both write-time and fix-time)

Only apply a clarity edit when ALL FOUR of these hold. If any one fails, **skip silently** — no flag, no report, no edit.

1. **You can name** the specific Delphi concept, class member, idiom, or reader confusion the original sentence misdescribes or buries. If you can't name it from doc context + linked PAS files, see *Resolving antecedents* below.
2. **The rewrite is shorter AND more specific.** If you can't make it shorter without losing meaning, skip. Same-length rewrites are style edits, not clarity wins.
3. **The rewrite preserves the author's voice.** See *Style invariants* below.
4. **The rewrite uses named subjects and concrete verbs.** No abstract scaffolding ("there is an issue where...", "this can occur when...", "in certain situations...").

If you find yourself writing "this could be clearer" as the reason, skip. If you can't name the specific Delphi concept, skip. If your rewrite is longer than the original, skip.

---

## Read targets fully — never partial

When fixing or auditing an MD file, read the **whole file** before making any edit. Partial reads create inconsistencies: section 7 might use a noun defined in section 2 in a way you'd "fix" if you only saw section 7. The author may have redefined a standard Delphi term locally — whole-file read catches that; partial doesn't.

Same rule for PAS files when you need them (see *Resolving antecedents*): read whole, not partial.

---

## Resolving antecedents (when "the handler" / "the destructor" / etc. needs a name)

Ambiguous documentation equals no documentation. When an anti-pattern hit requires naming a specific Delphi identifier, follow this procedure until you find the answer or exhaust the steps:

1. **Re-read the surrounding MD context** — the whole section the sentence lives in, then the section above. Most antecedents are named within two sections.
2. **Read any PAS file named by name in the same MD** — if the MD says "see `uLibrary.pas`", read `uLibrary.pas` whole.
3. **Grep the project's PAS files** for the relevant class or member name. The class is usually `T<Something>` near the noun in question; `Destroy`, `Create`, event handlers like `btnXClick` are findable by name.
4. **If still not found** — the ambiguity is intractable. Skip the edit. (This is the only case where the high-bar rule's clause 1 fails legitimately.)

Yes this costs tokens. The user has explicitly accepted that cost: ambiguous documentation is worse than no documentation.

---

## Anti-patterns (seed — generalize from these)

The 6 anti-patterns below are *seeds*. If you see a different but clearly-analogous clarity problem and all four high-bar rules hold, fix it. This is not an enumeration.

### 1. Vague pronoun where a named Delphi noun would land harder

Replace pronouns / category nouns ("the handler", "the routine", "the system", "the object") with the actual class member name. Resolve the antecedent if needed.

- **Bad:** "The handler runs on shutdown and persists state."
- **Good:** "`FormPreRelease` runs on shutdown and persists state."

Reasoning: a Delphi reader will hunt for the named identifier in the IDE; "the handler" forces them to guess.

### 2. Foreign-framework mental model

Treating Delphi forms like React components, `FormCreate` like a JS constructor, `procedure of object` like a JS callback function. Use the Delphi noun for the Delphi concept. Watch for the **JS/web/graphics-framework borrowed-metaphor family** — these words have a Delphi reading but the author usually means the foreign one:

- **"wire" / "wires up" / "wiring"** — JS event-system vocabulary. In Delphi you *assign* an event handler or *register* a callback.
- **"stub out" / "stubbed out"** — JS/web placeholder vocabulary. In Delphi say "not wired up" / "the unit is not loaded" / "the call is commented out" — or just name what's missing.
- **"surface"** — graphics-framework abstraction word borrowed as a vague noun for "feature" or "subsystem". Name the actual thing: the viewer, the control, the unit, the class.
- **"shim"** — JS placeholder vocabulary. Delphi has legitimate OS/COM shims, but most uses mean "stub" / "wrapper" — say which.
- **"hook into" / "hooks into"** — JS event-system vocabulary. Delphi has legitimate Win32 hooks and OTA notifiers; most uses mean "assigns to" / "subscribes to" / "registers with".
- **"scaffold" / "scaffolding"** — Rails/JS code-generator vocabulary. Say "skeleton" or "starter code".
- **"boilerplate"** — generic foreign vocabulary. Say "repeated setup" or name the specific repeated thing.

Examples:

- **Bad:** "`FormCreate` wires up the buttons."

- **Good:** "`FormCreate` assigns `btnSaveClick` to `btnSave.OnClick`."

- **Bad:** "The PDF surface is stubbed out for FMX."

- **Good:** "The FMX PDF viewer (`DX.Pdfium4D`) is not yet wired up."

- **Bad:** "`uLicensing` hooks into the form lifecycle."

- **Good:** "`uLicensing.RegisterFormHandlers` subscribes to `Application.OnIdle`."

Reasoning: Delphi forms have BOTH a `Create` constructor AND a `FormCreate` event. Conflating them silently mis-teaches the reader. Borrowed-framework metaphors obscure *which Delphi mechanism* is doing the work — design-time DFM/FMX assignment, runtime event handler assignment, Win32 message hook, OTA notifier, or unit `initialization` section.

The vocabulary table in `vocabulary.md` Section A auto-replaces the unambiguous ones (stub out, scaffold, boilerplate); Section B flags the context-dependent ones (surface, shim, hook into) for human review.

### 3. Bury-the-lede

Put the concrete Delphi fact FIRST in the sentence, not buried at the end behind framing.

- **Bad:** "There is a visibility issue with the GetPage method of the TPdfDocument class — it is actually private."
- **Good:** "`TPdfDocument.GetPage` is **private**."

Reasoning: Delphi readers scan for `Identifier.Member` patterns and bold warnings. Leading with framing hides the load-bearing fact.

### 4. Imprecise Delphi noun — name the exact class member

When you mean one specific class member, **name it** — class + member. Watch especially for words that imply plurality when you mean a single one ("chain", "stack", "set of", "list of"). Either name the count or name the single member. If you can't, run *Resolving antecedents*.

- **Bad:** "The destructor chain runs on shutdown."
- **Good:** "`TLibrary.Destroy` runs on shutdown."

Reasoning: "destructor chain" implies multiple destructors. If you mean one, name it; if you mean several, list them. The same rule applies to "the constructor" → "`TBook.Create`", "the event handler" → "`btnActivateClick`", "the property setter" → "`SetPageIndex`", "the callback" → either the event name or "anonymous method".

### 5. C-style imperative for a Delphi idiom

Operations that have a clean Delphi RTL/VCL/FMX idiom should be described by *naming the class doing the work*, not by walking through the imperative C steps.

- **Bad:** "Open the file, read N bytes, parse the header, close the file."
- **Good:** "`TStreamReader` reads the file in one pass."

Reasoning: Delphi readers know the RTL idioms. Spelling them out as C-style steps wastes the reader's time and obscures *which* class is doing the work.

**Exception:** if the doc is specifically explaining a *non-idiomatic* path ("we deliberately bypass `TStreamReader` because..."), the imperative steps may be load-bearing. Don't compress them.

### 6. Verbose abstract sentences

Cause-effect with named subjects and concrete verbs. No "there is an issue where..." / "this can occur when..." / "in certain situations..." abstract scaffolding when a direct sentence with named subjects works.

- **Bad:** "The application crashed during shutdown because the licensing object had already been freed when the form attempted to access it."
- **Good:** "Crashed because `Book.License` was freed before `FormPreRelease` ran."

Reasoning: half the words, twice the information.

**Critical caveat — do NOT compress an explanation into a fact.** History / Lessons-learned / Why-we-did-X subsections are *deliberately* verbose: the context IS the value. If you find yourself compressing a paragraph of "here's why this approach was wrong and what we tried before" into a single sentence, you are deleting load-bearing context. Skip.

This anti-pattern targets **abstract padding around a simple fact**, not **contextual explanation around a complex decision**.

### 7. Telling the reader things they don't need

Before writing anything, ask: *who is the reader, and what do they already know?* If the sentence tells them something they already know — or something irrelevant to the decision being justified — cut it. This is the more general form of anti-pattern #6: targeted at **over-documentation** (too many facts, all true), not abstract padding.

Five sub-patterns to catch:

- **Implementation trivia that doesn't change the comment's point.** Parenthetical detail that's true but doesn't help the reader of *this* sentence understand the decision being justified.
- **Naming the API that wasn't used.** If a comment justifies *why* the code does NOT use approach X, it is not the place to teach the reader the API for approach X. That belongs near a code site that uses it, or in framework docs.
- **Documenting the project's own framework.** For a project's own code, comments should not re-explain the project's own library/framework. The reader (the project owner) already knows it. Comments should explain why *this specific function* makes the choices it does, not catalogue the library.
- **Re-narrating well-named code.** When a property name + a literal value already tell the reader what is being set ("`Delay := 10`", "`CheckEvery := 24`", "`ShowConnectFail := FALSE`"), an inline comment that re-states the same fact in English ("// seconds before first check", "// hours between automatic checks", "// silent on offline") adds nothing. Only keep the inline comment if it says *why this value and not another* — a decision the reader cannot recover from the code.
- **Two jobs in one block comment.** When a block comment combines a *section label* (typography — "what block of code is this?") with a *decision note* (why a specific non-obvious choice), it is doing two distinct jobs. Split it: the section label becomes `{ # Label }` on its own line (PAS spacer form); the decision note becomes a separate `{ ... }` block (or `{ Note: ... }` if you want emphasis) on the next line. Different jobs deserve different forms. The fix here is **split-and-extract**, not delete. Example: `{ Touch + gesture wiring for pinch-zoom. Pan is intentionally NOT in the set — TScrollBox handles touch panning. }` becomes two comments: `{ # Pinch-zoom and double-tap-to-fit }` then `{ Note: Pan is intentionally NOT in the set — TScrollBox handles touch panning. }`.

**Example 1 — over-detailed lead-in comment**

- **Bad (5 lines, 6 claims):**
  
  ```
  GUI setup — force max-height vertical layout for the reader.
  VCL used Monitor.WorkareaRect (excludes taskbar) on TForm.
  FMX TCommonCustomForm has no Monitor property; the cross-platform equivalent is Screen.DisplayFromForm(Self).
  On mobile the form is fullscreen anyway, so the resize is desktop-only.
  Width and Left are still restored from INI by AutoState (asPosOnly).
  ```
- **Good (3 lines, 3 claims):**
  
  ```
  We force the reader to be as tall as the screen (more appropriate for reading a book).
  We cannot use Monitor.WorkareaRect because it only exists under VCL.
  On mobile the form is fullscreen anyway.
  ```

Reasoning: every removed line was either (a) implementation trivia (`excludes taskbar`), (b) the API we didn't use (`Screen.DisplayFromForm(Self)`), or (c) library behaviour the reader presumed-knows (`AutoState restores Width and Left`). The remaining lines justify the decision and qualify it.

**Example 2 — heavy block comment + redundant inline narration**

- **Bad (block comment recapping TUpdater + inline narration of every property):**
  
  ```
  { Auto-updater — checks an online INI for new releases / news. Non-blocking (uses an
    internal TTimer with Delay seconds before the HTTP call). ShowConnectFail=False so
    offline machines / firewalled networks log silently rather than popping a dialog on
    every launch. The "Check for updates..." menu item lets the user trigger a manual
    check (TfrmUpdater modal) regardless of the timer state.
    Single-instance: ciUpdater asserts Updater=NIL in TUpdater.Create — we only call
    Create once per process, freed in FormPreRelease. }
  if Updater = NIL then
   begin
     Updater:= TUpdater.Create(UpdaterNewsURL);
     ...
     Updater.Delay          := 10;       // seconds before first check; lets the form finish drawing
     Updater.CheckEvery     := 24;       // hours between automatic checks
     Updater.ShowConnectFail:= FALSE;    // silent on offline — the manual menu still surfaces errors
     Updater.OnConnectError := UpdaterConnectError;     // log instead of crashing
     Updater.Load;                       // restore last-check timestamp from INI
     ...
   end;
  ```
- **Good (one-line header + two inline `// why` comments):**
  
  ```
  { Auto-updater for new releases / news. }
  if Updater = NIL then
   begin
     Updater:= TUpdater.Create(UpdaterNewsURL);
     ...
     Updater.Delay          := 10;       // wait for the form to finish drawing before first HTTP call
     Updater.CheckEvery     := 24;
     Updater.ShowConnectFail:= FALSE;    // silent on auto-check; manual menu still shows errors
     Updater.OnConnectError := UpdaterConnectError;
     Updater.Load;
     ...
   end;
  ```

Reasoning: the block comment was re-documenting `TUpdater` (which lives in its own unit) — sub-pattern (c). The inline comments were re-narrating self-naming code — sub-pattern (d): `// hours between automatic checks` adds nothing that `CheckEvery := 24` doesn't already say. Only `Delay := 10` and `ShowConnectFail := FALSE` needed comments because the literal value alone doesn't justify itself — those got `// why` comments. The rest trusts the code.

**Difference vs anti-pattern #6:** #6 attacks *abstract padding* around a single fact ("there is an issue where..."). This anti-pattern attacks *over-detailed factual padding* — too many true facts, none of which the reader needs.

**Caveat — same as #6.** Do not compress History / Lessons-learned / Why-we-did-X subsections. Their verbosity IS the value. This anti-pattern targets over-detail in routine comments, not contextual explanation in historical sections.

### 8. Hard-wrapped block comments

Don't manually wrap long comment text across multiple lines. Write each comment as one logical line and let the editor soft-wrap. Hard-wraps freeze the line breaks at whatever editor width the author had open, look ragged at every other width, and force the reader's eye to re-anchor on each line for no benefit.

- **Bad (hard-wrapped across 3 lines):**
  
  ```
  { PDFiumDllDir is a global from the VCL PdfiumLib unit. With the PDF surface stubbed out
    for FMX (DX.Pdfium4D wiring is Phase 3b), the location-of-pdfium.dll hand-off doesn't apply;
    DX.Pdfium4D loads libpdfium per-platform via static external references. }
  ```
- **Good (one logical line — editor soft-wraps):**
  
  ```
  { PDFiumDllDir is the VCL PdfiumLib global pointing to libpdfium.dll. Not needed here: DX.Pdfium4D (the FMX viewer, Phase 3b) links libpdfium statically per platform. }
  ```

Scope: **PAS-comment mode only.** MD files have their own wrapping conventions (some authors prefer one-sentence-per-line, some prefer no wrap, some prefer prose-wrap at 80) — this rule does NOT apply to MD body text.

**Exceptions — keep the hard line break:**

- Lists inside a comment (`{ - item one \n - item two }`) — the line break is structural.
- Code examples or ASCII tables inside a comment.
- A deliberate two-paragraph comment where the blank line separates distinct thoughts.
- Section-label spacer comments (`{ # Auto-updater }`) — they're one line by construction.

Reasoning: comments are read in the IDE, which soft-wraps. Hard-wraps are typography for a fixed-width medium (print, fixed-width terminals). Comments are not that medium.

### 9. Mid-sentence parenthetical em-dashes

Mid-sentence em-dashes ("the agent — through hooks — does X") are a tic from other writing styles. The author dislikes them. Replace with parentheses or restructure into plain prose.

- **Bad:** "The agent — through a series of hooks — does X."
- **Good:** "The agent (using hooks) does X." OR "Using hooks, the agent does X."

Scope: **only mid-sentence parenthetical em-dashes.** These STAY:

- Sentence-terminator dashes — "It worked — finally."
- List bullet markers in markdown (`- item`).
- Em-dashes in `vocabulary.md` table headers (`---|---`).
- Em-dashes inside fenced code blocks.

Reasoning: parentheses or comma clauses do the same job without the typographic affectation.

---

## Style invariants 

These look like things an editor would "improve." They are deliberate. Leave them.

1. **Sentence fragments as paragraph kickers.** "Read the unit header." / "Two cooperating defects:" — fragments that lead a paragraph stay as fragments.
2. **Inline file:line citations — preserve existing, don't add new.** Existing `uLibrary.pas:113` stays. Never strip an existing citation. Never insert a new one — they go stale and the agent is not in the business of validating them. Out of scope to add.
3. **Bold + caps warnings.** "**Do not re-clone the repo without re-applying Patch 2.**" These are intentional hard warnings. Never soften or reformat.
4. **Mid-sentence parentheticals carrying real info.** "(`uLibrary.pas:113`)", "(see History below)", "(rejected with 'The key is not for this product!')" — these are content, not asides. Preserve.
5. **History / Lessons-learned / Why-we-did-X subsections — verbatim.** The contextual padding IS the value. Never compress, summarize, or reorder. Vocabulary fixes allowed inside; clarity fixes are not.
6. **Section-header style.** "The trap" / "The workaround" / "Why we needed both layers" — concrete naming of the thing being discussed. Do not rename to generic "Issue" / "Solution" / "Background".
7. **`{ # Label }` spacer comments in PAS code (PAS-comment-mode only).** When invoked on a PAS file's comments, these two-or-three-word spacer comments (form: `{ # Auto-updater }`, `{ # Form setup }`) are structural typography — the PAS equivalent of MD's `##` headers — and load-bearing for scannability. They look like minimal redundant comments but they aren't. Never delete, never expand into a sentence, never reformat. Preserve verbatim. (This invariant fires only in PAS-comment scope; MD files use real `##` headers and don't have this form.)

---

## When to skip even if you see a pattern

In addition to the high-bar rule's four clauses:

- **Opinionated style choice.** The author uses a specific word or framing repeatedly and consistently — that's their style, not an error. Skip.
- **Content vs. wording.** If the underlying *content* would need to change to make the sentence clearer, that's not a clarity edit — that's a content edit. Out of scope. Skip.
- **Code blocks, inline backticks, URLs, link text.** Never edited.
- **Inside a quoted user statement or quoted error message.** Never edited.

(Antecedent ambiguity is no longer a skip reason by default — resolve it via the procedure above. Skip only after exhausting steps 1–3.)

---

## Self-acceptance check before applying any edit

Before writing the Edit, privately confirm:

- Is the rewrite **shorter** than the original?
- Does it name a **specific** Delphi identifier, class member, or RTL/VCL/FMX class?
- Does it preserve every fragment, file:line citation, bold warning, and parenthetical aside?
- Does it remove abstract scaffolding ("there is...", "this can...", "in certain...")?

If any answer is "no" or "I'm not sure" — **skip silently**. Do not log the skip. Do not flag the sentence. Move on.

---

## What this file is NOT

- Not a complete enumeration. The 9 anti-patterns are seeds; generalize.
- Not a style guide for new prose unrelated to Delphi. Write any Markdown idiomatically; this file only governs Delphi-specific clarity and the listed invariants.
- Not a vocabulary list. Word-level fixes live in `vocabulary.md`.
