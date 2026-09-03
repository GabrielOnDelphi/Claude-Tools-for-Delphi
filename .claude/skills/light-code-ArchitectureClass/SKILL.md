---
name: light-code-ArchitectureClass
description: Audit a Delphi project's own classes (INCLUDING forms) for bad shapes — god classes, anemic data classes, misplaced responsibility, fat config records, shared mutable singletons, Ex-downcast holders. Reports ranked reshapes (extract-class, move-method, replace-singleton); never refactors. Say "is this a god class", "review the class design", "find anemic classes". For UNIT merges use light-code-ArchitectureUnit.
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-code-ArchitectureClass — Find ill-shaped classes (launcher)

This skill is a thin launcher. The audit is done by the **`light-code-ArchitectureClass` agent** in its
own context window, so the whole-project class read does not clog the main context — only the ranked
report comes back. Do not map or analyse classes yourself; resolve the scope, then launch the agent.

## When to run

- User invokes `/light-code-ArchitectureClass` (with or without args).
- User says variants: "is this a god class", "review the class design", "find anemic classes", "which classes carry too many responsibilities", "audit the class shapes".

If the real question is whether two **units/files** should merge, this is the wrong skill — point at
`/light-code-ArchitectureUnit`.

## Steps

1. **Resolve scope.** From `$args`: a path, a folder, or several files. With no argument, the scope is
   the project's own app source classes under the project root, **including form and frame classes**.
   Pass `--include-lightsaber` through if the user gave it. You do not need to ask anything — the agent
   applies the skip rules (LightSaber, third-party, tests) itself.
2. **Launch the `light-code-ArchitectureClass` agent** via the Agent tool with
   `subagent_type: light-code-ArchitectureClass`. Put the resolved scope (and any flags) in the prompt.
3. **Print the agent's returned report** verbatim. It is already self-contained (ranked candidates +
   verdict line). Do not re-analyse or second-guess its verdicts.

The agent ALSO writes a self-contained `HandOver.md` to the project root automatically, so a fresh
session can implement the reshapes from that file alone. Mention the path when you relay the report.

That's it. No mapping, no signal-walking, no edits in the skill itself.

## Where the rules live (for the agent, not for you)

- `../light-code-ArchitectureUnit/references/architecture-principles.md` — the shared deep/shallow
  model, counter-analysis discipline, LightSaber boundary, risk flags (read by both this and the
  ArchitectureUnit agent).
- The agent's own file (`.claude/agents/light-code-ArchitectureClass.md`) — the class-specific signals,
  anti-signals, procedure, report format, the mandatory HandOver.md write, and hard rules.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
