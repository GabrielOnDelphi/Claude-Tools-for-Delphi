---
name: light-web-YoutubeSummarizer
description: Turn a long video into the short version you can actually learn from. Takes a YouTube URL or id, a browser-saved .url shortcut, a folder holding either, or an already-saved transcript .txt. Extracts, cleans, summarizes — adding an "apply it" section when the video teaches something usable for Delphi code or for the Claude Code / AI workflow. Use on a pasted youtube.com or youtu.be link, on "summarize this video", "extract the transcript", "what can I learn from this", or on a file in `c:\AI\Claude Code\Transcripts\`.
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-web-YoutubeSummarizer — Video → the short version

Thin launcher. Resolve the transcript path(s), ask where to save, launch the **`light-web-YoutubeSummarizer`** agent once per file, relay what comes back. You never clean or summarize yourself.

## Step 0 — URL → transcript

If `$args` holds a YouTube link (`youtube.com/watch?v=`, `youtu.be/`, `/shorts/`) or a bare 11-char id, get a transcript first:

```
python "c:\Users\<you>\.claude\skills\light-web-YoutubeSummarizer\scripts\extract_transcript.py" "<URL-or-id>" ["<output dir>"]
```

- **Last stdout line = the transcript path.** Fallback: glob the output dir for the newest `*(transcript).txt`.
- Default output dir is `C:\AI\Claude Code\Transcripts\`. ffmpeg is not used and not needed. Non-zero exit prints a specific reason on stderr — no English captions, or yt-dlp itself failed. Relay that reason and stop; do not retry blindly.
- Filenames may hold full-width `？` `｜` (yt-dlp sanitises `?`/`|`). Read/Write/Agent handle them; only a picky PowerShell step needs an ASCII copy.

**`.url` shortcuts count as links.** A browser-saved `.url` is an INI file whose `URL=` line holds the address. Read it, take that value, extract **into the folder the `.url` lives in** — that is where he expects the transcript and summary, not the default folder.

**Never re-download.** Before extracting, check the target folder for an existing `*(transcript).txt` and use it. Re-extract only if he asks for a fresh one.

Several URLs → run once per URL, collect the paths.

## Step 1 — Resolve the input

Build the **transcript list** from `$args` (extracted paths count as explicit inputs):

- **Explicit `.txt` path(s)** → use as-is.
- **A folder** → Glob `*.txt` **and `*.url`**; each `.url` goes back through Step 0. A folder holding only a `.url` is the normal case after saving a link from the browser — it is not empty, don't report it as such. Skip files ending in `(summary)`. If both `X.txt` and `X (cleaned).txt` exist, keep only the cleaned one.
- **A folder holding subfolders** — the normal shape of `c:\AI\Claude Code\Transcripts\`, one folder per video. Glob `*/*.txt` and `*/*.url` **as well**, one level down. A subfolder that already holds a `*(summary).md` is done: leave it out unless he named it. Never report the parent as empty because its top level has no `.txt`.
- **Nothing** → ask for the path, defaulting to `c:\AI\Claude Code\Transcripts\`. If exactly one un-summarized video turns up there (top level or one level down), offer it.

Print the resolved list before launching.

## Step 2 — Save location, then launch

Subagents cannot prompt, so **you** settle this. **Skip the question when the location is obvious** — he pointed at a folder, or at a `.url` inside one: policy 1 is implied, say so in one line and go. Ask only for a bare URL with no folder context. One `AskUserQuestion`:

1. **Next to its transcript** (Recommended) — `<dir>/<title> (summary).md`, where `<title>` is the basename with **both** `(cleaned)` and `(transcript)` stripped. `X (transcript) (cleaned).txt` → `X (summary).md`, never `X (transcript) (summary).md`.
2. **All to** `c:\AI\Claude Code\Transcripts\` — same basename
3. **Don't save** — return in chat only

Then call **Agent** with `subagent_type: "light-web-YoutubeSummarizer"` once per file, passing the single file path and the concrete `OutputPath` (or "don't save"). Parallel is fine — nothing left to prompt for.

The agent cleans → reads whole → routes the topic to a lens → verifies the load-bearing claims → returns only the summary. Relay each one.

## Lenses (edit these, not the agent)

The "apply it" section is driven by three reference files the agent reads only when the topic calls for one — [references/lens-code.md](references/lens-code.md) (Delphi 13 / LightSaber stack, build, tests, style), [references/lens-ai.md](references/lens-ai.md) (skills, subagents, hooks, effort, MCP, memory), and [references/lens-factual.md](references/lens-factual.md) (a video that teaches no technique but feeds a real decision outside software — medical, a purchase, legal: a verbatim four-part inventory instead of an adaptation). Change what an adaptation knows about by editing the lens, not the agent prompt.

## Step 3 — Close

Several transcripts → one-line index of what was summarized and where it landed. A single file needs no wrap-up.

When the summary was saved to disk, end your reply with EXACTLY these three lines, verbatim, as the very last thing — nothing after them:

```
__________

Summarization done. Do you want me to open the file [Y/N]
```

Skip it entirely when nothing was saved (policy 3, "don't save").

**On `N`, or anything that isn't yes** — say nothing and stop. Do not re-offer.

**On `Y`** — open it with this exact command, nothing else:

```powershell
Remove-Item Env:CLAUDECODE, Env:CLAUDE_PID, Env:CLAUDE_CODE_SESSION_ID, Env:CLAUDE_CODE_CHILD_SESSION, Env:CLAUDE_CODE_BRIDGE_SESSION_ID, Env:CLAUDE_CODE_ENTRYPOINT -ErrorAction SilentlyContinue
explorer.exe "<absolute path to the .md>"
```

Two reasons for that shape, and neither is optional:

- **Strip the Claude variables first.** A Windows process keeps its parent's environment for life. If the editor starts as a child of this session it inherits `CLAUDE_CODE_*`, and anything it later launches — a VS Code integrated terminal, a Notepad++ Run entry — looks to Claude Code like a nested call and **silently stops saving the transcript**. Removing them in the same call is what makes the launch safe; the removal affects only that one call, never the session.
- **Go through `explorer.exe`, never `start`/`cmd`/`Start-Process`.** The intent is that the already-running shell owns the launch, so the editor never joins this session's process tree — `cmd //c start` definitely does the opposite and makes the editor our descendant. [UNVERIFIED: measuring the hand-off needs to spawn a process, which the permission classifier blocks — so treat the env-stripping above as the thing that actually guarantees safety, not this.]

Report only that it was opened. Never open anything the user did not answer `Y` to, and never open a second file "while you are at it".

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
