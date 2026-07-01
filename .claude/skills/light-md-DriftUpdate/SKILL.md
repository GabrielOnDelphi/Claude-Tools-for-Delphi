---
name: light-md-DriftUpdate
description: Scan project markdown docs (CLAUDE.md, README.md, docs/*.md) for drift after code changes. Flag sections out of sync with current code — class names, file paths, settings keys, procedure signatures, architecture claims. Propose concrete edits. Use when user says "update md", "check docs", "refresh claude.md", "verify docs", or invokes /light-md-DriftUpdate.
---

# Update MD docs

Scan markdown docs in current project. Find drift between doc claims and current code. Propose fixes.

## When to run

User invokes `/light-md-DriftUpdate` OR says variant: "update md", "check docs", "verify docs", "refresh claude.md", "are the docs still accurate", "doc drift check".

Also run proactively IF all of these hold:
- Session touched 3+ source files (code changes, not just reads)
- User about to end turn / close / commit
- Project has CLAUDE.md

If uncertain, ask first.

## Steps

1. **Detect Delphi project.** If the project root contains `*.dpr`, `*.dpk`, or `*.dproj`, read these two files into context BEFORE any Edit:
   - `../light-md-DelphiIdiom/references/vocabulary.md`
   - `../light-md-DelphiIdiom/references/writing-good-md.md`

   Reason: drift fixes that introduce new prose must use Delphi vocabulary (`nil` not `null`, `unit` not `module`, etc.) from the first write — otherwise `/light-md-DelphiIdiom` has to rewrite them afterward. Load once, apply throughout.
2. Glob `**/*.md` under current project root. Exclude: `node_modules/`, `.git/`, `build/`, `Win32/`, `Win64/`, `__history/`, `*.dproj/`, `External/`, vendored deps.
3. For each MD, Read fully.
4. Extract verifiable claims. Types:
   - Class/type/interface names (`TFoo`, `IBar`)
   - Unit / file names (`ClaudeUsage.Tray.pas`)
   - File paths (relative + absolute)
   - Procedure / method signatures with arg lists
   - Settings / config / INI / JSON field names
   - Enum values, constants
   - "Main form inherits X", "Uses Y framework"-style architecture bullets
5. Verify each claim:
   - Grep codebase for identifier
   - Check file exists at stated path
   - Confirm signature matches current code
6. Report drift per file. Group by: **broken** (claim false now), **stale** (partially wrong), **new** (code exists but undocumented section would add value).
7. Propose **specific Edit tool calls** with old_string / new_string. No hand-wavy "update this section".
8. Print the report, then apply all three categories directly via Edit — NO confirmation prompts. Exception: if a proposed change is destructive / irreversible (deletes a large section, rewrites more than a few lines, touches a file outside the MD scope), ask before applying that specific item. On Delphi projects, every Edit must honor the rules from step 1.

## Skip

- Design rationale / "why" sections — low drift risk, hard to verify
- Intent, philosophy, tradeoff discussions
- Historical notes, bug reports, changelogs (`CHANGELOG.md`, `HISTORY.md`)
- User-facing docs describing features (run app to verify — out of scope)
- Licenses, contributor lists

## Output format

```
=== CLAUDE.md ===
BROKEN:
  Line 82: "TSessionEntry" — renamed to TUsageEntry
    Fix: replace "TSessionEntry" → "TUsageEntry" (3 occurrences, lines 82, 131, 204)
  Line 157: path "ClaudeUsage.Chart.pas" — file moved to "Lib/ClaudeUsage.Chart.pas"

STALE:
  Line 104: "TSettings record owns Load/Save" — still true, but new field MinYAxis
           missing from bullet list (line 115)

NEW (optional):
  Tray balloon hints added in LightFmx.Common.SysTray — no doc mention

Applying all fixes...
```

After printing the report, run the Edit calls for every BROKEN / STALE / NEW item in the same response. Do not wait for per-category approval.

## Scoping heuristics

Big projects have many MDs. If >20 found, ask user which scope:
- Root only (`CLAUDE.md`, `README.md`)
- Root + `docs/`
- All

Default: root only unless user says otherwise.

## Anti-patterns

- DO NOT rewrite whole files — surgical Edits only
- DO NOT "improve" prose style — user wrote it that way on purpose
- DO NOT add marketing fluff, emojis, or headers not in original voice
- DO NOT remove `///` Delphi comments or similar "temporarily disabled" markers
- DO NOT touch LICENSE, CHANGELOG, or user-written tutorials
