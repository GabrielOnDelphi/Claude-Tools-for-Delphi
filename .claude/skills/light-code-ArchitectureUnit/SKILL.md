---
name: light-code-ArchitectureUnit
description: Audit a Delphi project's own units (files) for SHALLOW modules that should merge into one deep module — information leakage, temporal decomposition, pass-through layers, always-paired usage. Reports ranked merge candidates; never merges. Say "find shallow units", "what units should be merged". For CLASS shapes use light-code-ArchitectureClass.
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-code-ArchitectureUnit — Find shallow units (launcher)

This skill is a thin launcher. The audit is done by the **`light-code-ArchitectureUnit` agent** in its
own context window, so the whole-project read does not clog the main context — only the ranked report
comes back. Do not map units or analyse them yourself; resolve the scope, then launch the agent.

## When to run

- User invokes `/light-code-ArchitectureUnit` (with or without args).
- User says variants: "find shallow units", "what units should be merged", "which files should be folded together", "audit the module structure".

If the real question is about a **class** shape (god class, anemic class, misplaced responsibility),
this is the wrong skill — point at `/light-code-ArchitectureClass`.

## Steps

1. **Resolve scope.** From `$args`: a path, a folder, or several files. With no argument, the scope is
   the project's own app source under the project root. Pass `--include-lightsaber` through if the user
   gave it. You do not need to ask anything — the agent applies the skip rules (LightSaber, third-party,
   tests, forms) itself.
2. **Launch the `light-code-ArchitectureUnit` agent** via the Agent tool with
   `subagent_type: light-code-ArchitectureUnit`. Put the resolved scope (and any flags) in the prompt.
3. **Print the agent's returned report** verbatim. It is already self-contained (ranked candidates +
   verdict line). Do not re-analyse or second-guess its verdicts.

That's it. No mapping, no signal-walking, no edits in the skill itself.

## Where the rules live (for the agent, not for you)

- `references/architecture-principles.md` — the shared deep/shallow model, counter-analysis discipline,
  LightSaber boundary, risk flags (read by both this and the ArchitectureClass agent).
- The agent's own file (`.claude/agents/light-code-ArchitectureUnit.md`) — the unit-specific signals,
  anti-signals, procedure, report format, and hard rules.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
