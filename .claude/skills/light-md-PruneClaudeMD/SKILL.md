---
name: light-md-PruneClaudeMD
description: Prune and tighten a CLAUDE.md (or any agent/skill instruction markdown) — cut bloat and duplication, fix stale/wrong rules, relayer misplaced content, reorder for adherence — without losing load-bearing info. Backs the file up first. Launches the light-md-PruneClaudeMD agent. Use when the user invokes `/light-md-PruneClaudeMD`, says "clean up this CLAUDE.md", "my CLAUDE.md is too long", "prune the docs", or "Claude keeps ignoring my rules".
---

# /light-md-PruneClaudeMD — Prune a CLAUDE.md

Thin launcher. Resolve the target file and launch the **`light-md-PruneClaudeMD`** agent. You do NOT prune yourself.

## Step 1 — Resolve the target

The argument is in `$args`.

- **An explicit `.md` path** → use it.
- **A folder** → the `CLAUDE.md` in it. If several nested `CLAUDE.md` exist, list them and ask which one (or all).
- **No argument** → the nearest project `./CLAUDE.md`. If none, ask which file.

Skip any `*-Backup.md`. Print the resolved target before launching.

## Step 2 — Launch the agent

Call the **Agent** tool with `subagent_type: "light-md-PruneClaudeMD"`. Pass the target path. The agent **backs the file up first** (`CLAUDE-Backup.md`), then applies in-file cuts / rewrites / stale-fact fixes, and **proposes** (does not execute) any cross-file move.

**Relay its final report** to the user.

## Step 3 — Summary + beep

Print a short summary (the full report is already in the transcript): backup path, size before → after, counts of cut / rewritten / stale-fixed, and the FLAGGED items that need a human decision.

Then beep once:

```
powershell -c "(New-Object Media.SoundPlayer 'c:\AI\Claude Code\Tools\task_done_beep.wav').PlaySync()"
```

## Rules

- **You don't prune; the agent does.** Resolve the target, launch, summarize.
- The agent **edits the target in place after backing it up**, but only **proposes** cross-file moves — relay those for the user to approve; never let it scatter content into other files unasked.
- **One beep, at the end.**
