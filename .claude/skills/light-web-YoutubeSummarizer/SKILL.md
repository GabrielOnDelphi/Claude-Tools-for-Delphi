---
name: light-web-YoutubeSummarizer
description: Summarize a YouTube transcript .txt file — cleans it first, then produces a structured summary (with a Delphi 13 / LightSaber adaptation section when the talk is about programming). Launches the light-web-YoutubeSummarizer agent. Use when the user invokes `/light-web-YoutubeSummarizer`, says "summarize this transcript", "what can I learn from this video for my Delphi work", or points at a file in c:\AI\Claude Code\Transcript\.
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-web-YoutubeSummarizer — Transcript Summarizer

This is a thin launcher. Your only job is to resolve the transcript path(s) and launch the
**`light-web-YoutubeSummarizer`** agent, once per file. You do NOT clean or summarize anything
yourself — the agent runs the cleanup script, reads the transcript, and returns only the final
summary. You (the launcher) ask where to save and pass the path to each agent.

## Step 1 — Resolve the input

The argument is in `$args`. The user may pass a single `.txt` path, several paths, a folder, or
nothing. Build the **transcript list**:

- **One or more explicit `.txt` paths** → use them as-is.
- **A folder** → Glob `<folder>/*.txt` for the file list. Skip any file whose base name ends
  with `(summary)` — those are outputs, not transcripts. If both `X.txt` and `X (cleaned).txt`
  exist, keep only the `(cleaned)` one (the agent handles cleaning, but no point feeding the raw
  twin as a second job).
- **No argument** → ask the user for the transcript path, defaulting to the scratch folder
  `c:\AI\Claude Code\Transcript\`. If that folder has exactly one un-summarized `.txt`, offer it.

Print the resolved transcript list before launching.

## Step 2 — Ask where to save, then launch the agents

Subagents cannot prompt the user, so **you** ask the save policy here — one `AskUserQuestion`, the
recommended option first:

1. **Save each summary next to its transcript** (Recommended) — `<dir>/<basename without "(cleaned)"> (summary).md`.
2. **Save all to** `c:\AI\Claude Code\Transcript\` — same basename.
3. **Don't save** — just return each summary in chat.

Then, for each file in the list, call the **Agent** tool with
`subagent_type: "light-web-YoutubeSummarizer"`, passing the single file path **and the concrete
`OutputPath`** you computed from the chosen policy (or "don't save"). They can run **in parallel** —
the save location is already resolved, so no interactive prompts collide.

The agent: cleans the transcript (if not already cleaned) → reads it whole
→ classifies the topic → writes the summary (adding the Delphi/LightSaber section for
programming talks) → returns only the summary.

**Relay each summary** the agent returns.

## Step 3 — Summary

If you processed several transcripts, print a one-line index of which were summarized and where
each was saved. For a single file, the agent's output is enough — no extra wrap-up needed.

## Rules

- **You do not summarize.** Resolving the path(s), asking the save location, launching the agent
  per file, and relaying results is your entire job. The agent does the cleaning and summarizing.
- **You ask where to save, not the agent.** Subagents cannot prompt the user — resolve the save
  location in the launcher and pass the concrete `OutputPath` to each agent.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*
