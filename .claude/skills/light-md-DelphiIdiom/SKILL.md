---
name: light-md-DelphiIdiom
description: Fix Delphi vocabulary and writing-clarity issues in Markdown docs — non-Delphi term swaps + bounded clarity rewrites. Say "check vocab", "fix vocabulary", "delphi terms", "clean up the md", or after writing/editing *.md in a Delphi project.
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# Delphi MD vocab + clarity check (launcher)

This skill is a thin launcher. The work is done by the `light-md-DelphiIdiom` agent. Do not load the dictionary or scan files yourself — that's the agent's job, in its own context window.

## When to run

- User invokes `/light-md-DelphiIdiom` (with or without args).
- User says variants: "check vocab", "fix vocabulary", "delphi terms", "vocab pass", "scan docs for vocab", "clean up the md", "fix the docs".
- Proactively: after writing or editing any `*.md` file in a Delphi project, run before claiming done.

If unsure whether a project is "Delphi", check for `*.dpr`, `*.dpk`, `*.dproj` in the project root or for `CLAUDE.md` mentioning Delphi. If still unsure, ask.

**Hard exclusion — never run on prose/manuscript MD.** This skill is for *Delphi-project source documentation* (CLAUDE.md, README, docs about code). It is NOT for long-form prose that merely *mentions* Delphi. Skip entirely — do not even resolve targets — when the file lives under a book/manuscript tree, in particular anything under a book/manuscript tree such as `c:\MyBooks\`. Those `.docx`/`.md` files have their own casual, honest writing voice (see that tree's own CLAUDE.md) that deliberately conflicts with the Delphi-vocabulary rules here. A folder having a `CLAUDE.md` that talks about Delphi is NOT enough — the test is "is this documentation *for code*?", not "does it mention Delphi?". When in doubt about a prose file, skip and say why.

## Invocation modes

| Form                       | Meaning                                              |
| -------------------------- | ---------------------------------------------------- |
| `/light-md-DelphiIdiom <file.md>`     | Scan + fix exactly that file                         |
| `/light-md-DelphiIdiom <glob>`        | Scan + fix every match (e.g. `c:\Projects\Foo\*.md`) |
| `/light-md-DelphiIdiom` (no args)     | Scan + fix every MD file edited in the current task  |

## Steps

1. **Resolve targets.**
   - With args: Glob the arg pattern.
   - No args: list MD files Write/Edited this task. If none — print "No MD files touched this task." and stop.

2. **Launch the `light-md-DelphiIdiom` agent** via the Agent tool with `subagent_type: light-md-DelphiIdiom`. Pass the resolved file list in the prompt. One agent for the whole batch — the agent processes files sequentially so it can accumulate cross-file pattern confirmations.

3. **Print the agent's returned report** verbatim.

That's it. No scanning, no dictionary loading, no edits in the skill itself.

## Where the rules live (for the agent, not for you)

- `~\.claude\skills\light-md-DelphiIdiom\references\vocabulary.md` — word-level rules
- `~\.claude\skills\light-md-DelphiIdiom\references\writing-good-md.md` — sentence-level clarity rules

These are loaded by the agent, not by this skill.

## Scope

- **Default:** MD files only (`*.md`, `*.markdown`).
- **PAS comments on explicit request:** if the user says "clean up the comments in `FooBar.pas`", pass that scope to the agent. Never autonomously expand to PAS.

## Extending the dictionary

When a Section D open question is resolved, edit `references/vocabulary.md`:

- Move the entry into A, B, or C as appropriate.
- Delete from D.
- Update the "Sources" section if a new citation is involved.
- Do not touch this SKILL.md unless the skill's behaviour itself needs to change.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*
