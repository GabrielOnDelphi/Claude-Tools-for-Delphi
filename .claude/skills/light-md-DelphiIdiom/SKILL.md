---
name: light-md-DelphiIdiom
description: Fix Delphi vocabulary and writing-clarity issues in the Markdown documentation of a Delphi project — swap terms borrowed from C, Java or Python for the Delphi word, plus bounded clarity rewrites. Say "check vocab", "fix vocabulary", "delphi terms", "vocab pass", "scan docs for vocab", "clean up the md", "fix the docs". Also fire it yourself, without being asked, after writing or editing any *.md in a Delphi project, before saying the work is done. Documentation only — it refuses .pas files, and it refuses book and manuscript prose such as anything under c:\MyBooks\, which has its own deliberately non-technical voice.
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# Delphi MD vocab + clarity check (launcher)

This skill is a thin launcher. The work is done by the `light-md-DelphiIdiom` agent. Do not load the dictionary or scan files yourself — that's the agent's job, in its own context window.

## Is this file in scope?

Two checks before resolving any target.

**Is the project a Delphi project?** Look for a `*.dpr`, `*.dpk` or `*.dproj` file in the project root, or a `CLAUDE.md` that talks about Delphi. If neither is there, ask.

**Is the file documentation for code, or is it prose?** This skill rewrites the documentation of Delphi source — `CLAUDE.md`, `README.md`, docs describing how the code works. It must never touch long-form prose that merely mentions Delphi. Anything under `c:\MyBooks\` is out of scope, and so is any other manuscript tree: those files are written in a casual, personal voice that the book tree's own `CLAUDE.md` defines and protects, and the vocabulary rules here would flatten it. A folder whose `CLAUDE.md` talks about Delphi is not enough to bring it in scope — the question is whether the file documents code, not whether it mentions Delphi. Skip a prose file without resolving it, and say why.

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

- `c:\Users\<you>\.claude\skills\light-md-DelphiIdiom\references\vocabulary.md` — word-level rules
- `c:\Users\<you>\.claude\skills\light-md-DelphiIdiom\references\writing-good-md.md` — sentence-level clarity rules

These are loaded by the agent, not by this skill.

## Scope - Markdown ONLY

- **This skill edits `*.md` and `*.markdown`. Nothing else.**
- **A `.pas` file is REFUSED, even when the user names one explicitly.** Do not pass it to the agent. Tell the user that Delphi source comments are a different job and this skill will not do it. Then carry on with any `.md` files in the same invocation.
- The reason is not tidiness. Cleaning source comments is the OPPOSITE operation - deletion. It cuts edit history, shortens what is left, and has to protect several kinds of comment this skill knows nothing about, starting with `///`, which in many Delphi codebases marks temporarily disabled code that is meant to come back. Letting the vocabulary rules loose on a `.pas` file would rewrite those instead of leaving them alone.
- Reading a `.pas` file to resolve an antecedent while editing Markdown is fine. Reading is not editing.

## Extending the dictionary

When a Section D open question is resolved, edit `references/vocabulary.md`:

- Move the entry into A, B, or C as appropriate.
- Delete from D.
- Update the "Sources" section if a new citation is involved.
- Do not touch this SKILL.md unless the skill's behaviour itself needs to change.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
