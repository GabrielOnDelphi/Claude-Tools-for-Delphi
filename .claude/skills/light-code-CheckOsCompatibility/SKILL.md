---
name: light-code-CheckOsCompatibility
description: Audit Delphi FMX source for cross-platform issues — Windows-only APIs, hardcoded paths, missing platform conditionals, mobile-incompatible patterns. Say "check this for Android/iOS", "is this safe on mobile/macOS/Linux", "audit for cross-platform issues".
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-code-CheckOsCompatibility — Cross-Platform Compatibility Audit

This is a thin launcher. Your only job is to resolve the input scope and launch the
**`light-code-CheckOsCompatibility`** agent. You do NOT audit the code yourself.

## Step 1 — Resolve the input

The argument is in `$args`. The user may pass a single `.pas` file, a folder, or several files.
Build the **audit set**:

- **One or more explicit file paths** → use them as-is.
- **A folder** → Glob `<folder>/**/*.pas` for the file list. If the result is large (more than
  ~25 files), tell the user the count and ask whether to audit all or narrow the scope.
- **No argument** → audit the `.pas` files with **uncommitted** changes. Run
  `git status --porcelain` and keep the `.pas` files it lists (modified, added, or renamed) —
  this is "the code I just changed". If that list is empty, ask the user which file or folder to
  audit. Do NOT default to the whole repository.

If the user names a target platform (Android, iOS, macOS, Linux), carry that into the agent's
prompt so it focuses there. Print the resolved audit set as a short list before launching.

## Step 2 — Launch the agent

Call the **Agent** tool with `subagent_type: "light-code-CheckOsCompatibility"`. Pass it the **full audit set**
in one prompt, plus any target platform the user mentioned. The agent reads the project
`CLAUDE.md` for the declared target platforms and intentional platform-specific code, scans the
files, and reports issues (Windows-only units/APIs, hardcoded paths, missing `{$IFDEF}` guards,
mobile-incompatible patterns).

**Relay its final report** to the user.

## Step 3 — Summary

Print a short summary (the agent's full report is already in the transcript — do not re-paste
it): how many files audited, how many issues by severity, and which need a human decision.

## Rules

- **You do not audit code.** Resolving the scope, launching the agent, and summarizing is your
  entire job. The agent does the audit.
- **This agent only reports** (its tools are read + web). It does not apply fixes — so do not
  promise fixes; relay the findings and let the user decide.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
