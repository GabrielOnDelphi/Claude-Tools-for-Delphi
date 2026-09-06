# Topic: AI / Claude Code workflow

> **This is the author's own Claude Code setup, kept as a worked example.** Replace the section
> "What the setup actually is" with your own skills, agents, hooks and models before using the
> skill, or the "apply it" section will adapt every video to somebody else's configuration.

Load this when the video teaches something about working with LLMs — prompting, agent design, context management, model choice, MCP, or a coding assistant (Claude Code, Cursor, Copilot, Codex). This is the most common applicable topic in Gabriel's transcript folder, so treat it with the same seriousness as the code topic file.

Section heading to use: `## Applying it to your Claude Code setup`

**The bar has not moved.** Being *about* AI earns nothing. A video on OpenAI's finances, model-release drama, or who controls AI teaches no technique — no topic section, however AI-heavy it is. The question stays: could he change something in his setup on Monday because of this?

## What his setup actually is

He is not a casual user — he runs a large, hand-built Claude Code configuration. Adaptations must name a real piece of it.

- **Skills** — several dozen in `c:\Users\<you>\.claude\skills\`, named `light-<category>-<Name>` (convention documented in that folder's `CLAUDE.md`). Count the folder if the number matters; do not quote one from here. Categories in use: book, bug, code, md, new, ref, review, security, task, tools, web. A video's idea usually lands as *a new skill in an existing category* or *a change to one that exists*.
- **Subagents** — a couple of dozen in `c:\Users\<you>\.claude\agents\`, several chained into pipelines (`light-review-step1/2/3`, book translate → verify). Standing rule from his global `CLAUDE.md`: **cap subagent use** — delegate only for genuinely large or parallel work, never to double-check your own. Any video pushing "spawn 20 agents" collides with this; say so.
- **Agent memory** — per-agent dirs under `c:\Users\<you>\.claude\agent-memory\<agent>\`, one fact per file with frontmatter, indexed in `MEMORY.md`.
- **Hooks** — `settings.json` runs `SessionStart`, `UserPromptSubmit`, `PreToolUse` and `Stop` hooks (e.g. `effort-report-hook.ps1`). Anything phrased as "make Claude always do X" is a hook question, not a prompt question.
- **Effort levels** — the live level arrives on the `ACTIVE EFFORT:` line. Frontmatter `effort:` applies **only when he types `/skill-name`**, is ignored on auto-invocation, and is silently overridden by the `CLAUDE_CODE_EFFORT_LEVEL` env var. Measured on v2.1.220, 2026-08-01. `ultrathink` in a prompt is not an effort change. A video claiming otherwise is wrong — check before repeating it.
- **Instruction layering** — global `c:\Users\<you>\.claude\CLAUDE.md`, per-folder `CLAUDE.md`, skill frontmatter, `statusline-command.md`, `keybindings.json`. Ideas about "context engineering" map onto which layer a rule belongs in.
- **Cross-session memory** — `HandOver.md` per project (durable, via `/light-md-HandOver`) plus `.claude/session-<task>.md` live notes. Any video about agent memory or continuity gets compared against this, not against a blank slate.
- **MCP servers connected** — `claude-in-chrome` (browser), `dpt-debugger` (Delphi debugger), `autopilot` / `autopilot-android` (drive a running app), Gmail, Google Calendar/Drive. He builds MCP consumers, not just uses them.
- **Model** — Opus 5 (`claude-opus-5`); the Claude 5 family plus Haiku 4.5. Cheap mechanical agents pin `haiku` (e.g. `light-compiler`).

## Verify harder here than anywhere else

AI-tooling videos age in weeks and are the single most common source of confident wrong claims.

- Model names, context sizes, pricing, rate limits, deprecations → check `docs.anthropic.com` / `platform.claude.com` via `WebFetch` or `WebSearch`. Never repeat a price or a token limit from a transcript.
- A claimed Claude Code feature (a flag, a hook event, a settings key, a slash command) → confirm it exists in the docs before suggesting he adopt it. Half of these are the speaker's own wrapper script, not a product feature.
- Benchmark claims → name the benchmark, the n, and who ran it. A five-build blind comparison is n=1 anecdote, not evidence.
- "Agent framework X beats Y" → almost always untested marketing. Report as the speaker's assertion.

## What tends to transplant, and what doesn't

- **Transplants well:** prompt and instruction structure, context-window discipline, verification/critical-thinking passes, memory file conventions, hook-driven automation, skill decomposition, when to escalate reasoning effort.
- **Usually doesn't:** anything assuming a Linux/Docker sandbox or a container per agent (he is on Windows with a whitelist firewall, and Delphi builds are IDE-and-licence-bound); huge parallel agent fleets (collides with his cap-subagent rule and with serialized MSBuild); paid third-party orchestration layers wrapping what his own skills already do; "just let it run overnight unsupervised" patterns on a machine where a restarted long-lived process silently kills transcript saving.

## Overlap with the code topic file

"Using AI to write code" hits both topic files — that is normal for him. Read both, then write **one** combined section rather than two competing ones.
