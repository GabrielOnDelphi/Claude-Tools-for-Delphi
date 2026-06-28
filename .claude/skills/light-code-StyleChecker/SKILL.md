---
name: light-code-StyleChecker
description: Scan imported or 3rd-party Delphi code for style compliance, common mistakes, and dangerous patterns (resource leaks, unsafe casts, missing try/finally). Launches the light-code-StyleChecker agent. Use when the user invokes `/light-code-StyleChecker`, says "check this 3rd-party unit", "scan the imported library", or "style-check SourceCode/". Do NOT use for our own project code — use /light-code-Review for that.
---

# /light-code-StyleChecker — 3rd-party Code Style Audit

This is a thin launcher. Your only job is to resolve the input scope and launch the
**`light-code-StyleChecker`** agent. You do NOT review code yourself.

**Scope reminder:** this skill is for IMPORTED / 3RD-PARTY Delphi code only. For our own
project code, the right tool is `/light-code-Review` (deeper, real correctness review). If the user
points this at our own code, say so and suggest `/light-code-Review` — then proceed only if they
confirm.

## Step 1 — Resolve the input

The argument is in `$args`. The user may pass a single `.pas` file, a folder, or several files.
Build the **scan set**:

- **One or more explicit file paths** → use them as-is.
- **A folder** → Glob `<folder>/**/*.pas` for the file list. If the result is large (more than
  ~25 files), tell the user the count and ask whether to scan all or narrow the scope.
- **No argument** → ask the user which imported file or folder to scan. Do NOT default to the
  whole repository, and do NOT fall back to `git status` — 3rd-party code is usually already
  committed, so a git-diff scope would miss it.

Print the resolved scan set as a short list before launching, so the user can see the scope.

## Step 2 — Launch the agent

Call the **Agent** tool with `subagent_type: "light-code-StyleChecker"`. Pass it the **full scan
set** in one prompt. Tell it plainly that this is imported / 3rd-party code to audit for style
compliance, common mistakes, and dangerous patterns.

The agent reads the project `CLAUDE.md` for conventions, scans the files, reports findings, and
applies the safe fixes it is confident about. It also applies four mandatory reformatting passes
on imported code: a LightSaber-format unit header, Embarcadero keyword casing, `if`/`then`/`else`
layout, and no line wrapping. **Relay its final report** to the user — do not re-derive or
second-guess it.

## Step 3 — Summary + beep

Print a short summary (the agent's full report is already in the transcript — do not re-paste
it): how many files scanned, how many issues found, how many fixed vs. flagged for a human
decision.

Then beep once so the AFK user knows it finished:

```
powershell -c "(New-Object Media.SoundPlayer 'c:\AI\Claude Code\claude bip.wav').PlaySync()"
```

## Rules

- **You do not review code.** Resolving the scope, launching the agent, and summarizing is your entire job. The agent does the audit.
- **3rd-party scope only.** If the target looks like our own project code, recommend `/light-code-Review` instead before proceeding.
- **One beep, at the end**, after the agent returns.
