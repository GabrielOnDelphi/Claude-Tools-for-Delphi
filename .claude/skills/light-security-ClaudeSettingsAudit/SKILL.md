---
name: light-security-ClaudeSettingsAudit
description: Audit Claude Code config files (settings.json, settings.local.json, .mcp.json) across the computer for unsafe or malicious content — hooks that run shell commands, credential/proxy env vars, arbitrary MCP servers, permission-bypass modes, over-broad allow rules. Classifies each finding DANGEROUS / SUSPICIOUS / SAFE. Read-only. Use when the user invokes `/light-security-ClaudeSettingsAudit`, says "check my settings.local.json for malware", "are my Claude permission files safe", "scan my Claude config", or "audit settings.json across the computer".
disable-model-invocation: true
---

# /light-security-ClaudeSettingsAudit — Claude Code config safety scan

This is a thin launcher. Your only job is to resolve the scope and launch the **`light-security-ClaudeSettingsAudit`** agent (pinned to Sonnet — the scan is mostly mechanical). You do NOT scan the files yourself.

## Step 1 — Resolve the scope

`$args` may name a folder or a single file to scan. If given, pass it as the scope. If empty, the default scope is the **whole machine** (the agent knows the roots to cover). If the user names extra trusted items or extra roots, carry them into the agent's prompt.

## Step 2 — Launch the agent

Call the **Agent** tool with `subagent_type: "light-security-ClaudeSettingsAudit"`. Pass the scope (or "whole machine, default roots") and any trust/extra-root notes in one prompt. The agent reads the classification at `references/settings-danger.md`, globs for config files, reads and classifies each, and returns the report.

## Step 3 — Relay

Print the agent's report verbatim — the verdict line, the per-bucket tables, and the coverage line. Do not soften or drop findings. If anything is DANGEROUS, say so plainly at the top.

## Notes

- **Read-only.** Removing or fixing a bad entry is a separate, explicit follow-up the user must request.
- The classification in `references/settings-danger.md` is the source of truth. Update it (and its `Sources` date) when Claude Code adds fields or the machine's known-good baseline changes. The agent reads it by absolute path.
- **Weekly run:** this skill can be scheduled. See the audit note in the project CLAUDE.md for the cron/Task-Scheduler wiring.
