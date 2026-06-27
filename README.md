# Claude Tools for Delphi

Claude Code agents and skills for **Delphi** development — the same tooling I use daily to build commercial Delphi apps.

## What's inside

| Folder    | Contents                                                                                                                                 |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `agents/` | Custom Claude Code agents (e.g. `light-style-checker` — scans 3rd-party Delphi units for unsafe patterns, leaks, missing `try/finally`). |
| `skills/` | Skill bundles that drive those agents from a slash command.                                                                              |

The agents are self-documented. 

## How to install

Drop an agent into `~/.claude/agents/` and a skill into `~/.claude/skills/`, then call it from any Claude Code session.
