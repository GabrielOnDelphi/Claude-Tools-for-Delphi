---
name: light-md-PruneClaudeMD
description: Prune and tighten a CLAUDE.md or other agent/skill instruction markdown — cut bloat/duplication, fix stale rules, relayer misplaced content, without losing load-bearing info. Backs up first. Say "clean up this CLAUDE.md", "my CLAUDE.md is too long".
disable-model-invocation: true
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

## Step 3 — Summary

Print a short summary (the full report is already in the transcript): backup path, size before → after, counts of cut / rewritten / stale-fixed, and the FLAGGED items that need a human decision.

## Rules

- **You don't prune; the agent does.** Resolve the target, launch, summarize.
- The agent **edits the target in place after backing it up**, but only **proposes** cross-file moves — relay those for the user to approve; never let it scatter content into other files unasked.
