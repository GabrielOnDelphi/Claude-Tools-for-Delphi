---
name: light-md-DriftUpdate
description: Scan project markdown docs (CLAUDE.md, README.md, docs/*.md) for drift after code changes. Flag sections out of sync with current code — class names, file paths, settings keys, procedure signatures, architecture claims. Propose and apply concrete edits. Use when the user says "update md", "check docs", "verify docs", "refresh claude.md", "are the docs still accurate", "doc drift check". Also fire it yourself, without being asked, when a session has changed 3 or more source files in a project that has a CLAUDE.md and the user is about to stop or commit — stale docs are only ever noticed later, by someone who trusted them.
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# Update MD docs (launcher)

This skill is a thin launcher. The scan-verify-fix work is done by the **`light-md-DriftUpdate` agent**
in its own context window (reading every doc + grepping the code is heavy — keep it out of the main
context). Your job: decide whether to run, resolve the scope, launch the agent, relay its report.

## Steps

1. **Resolve scope (ask here if needed — the agent cannot).** Glob `**/*.md` under the project root,
   excluding `node_modules/`, `.git/`, `build/`, `Win32/`, `Win64/`, `__history/`, `*.dproj/`,
   `External/`, vendored deps. If **more than ~20** MD files match, ask the user which scope:
   - Root only (`CLAUDE.md`, `README.md`) — the default if they don't care
   - Root + `docs/`
   - All

   With `$args` naming a file/glob, use that as the scope and skip the question.
2. **Launch the `light-md-DriftUpdate` agent** via the Agent tool with
   `subagent_type: light-md-DriftUpdate`. Pass the resolved scope (the concrete file list or the
   chosen breadth) in the prompt.
3. **Print the agent's returned report** verbatim. It lists BROKEN / STALE / NEW fixes it applied, plus
   any NEEDS CONFIRMATION items it left unapplied — surface those so the user can decide.

That's it. No scanning, no claim-verification, no edits in the skill itself — the agent does all of it
and applies the surgical fixes.

## Where the rules live (for the agent, not for you)

The agent loads the Delphi vocabulary + clarity references from
`c:\Users\<you>\.claude\skills\light-md-DelphiIdiom\references\` so any new prose it writes is already
Delphi-idiomatic, and it holds the claim-extraction / verify / skip / anti-pattern rules. See
`.claude/agents/light-md-DriftUpdate.md`.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
