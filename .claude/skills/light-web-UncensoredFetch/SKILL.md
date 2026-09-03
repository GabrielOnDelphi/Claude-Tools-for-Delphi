---
name: light-web-UncensoredFetch
description: Read ONE web page that Claude Code's built-in WebFetch refuses (the whole reddit.com domain is on WebFetch's denylist; also any Cloudflare-walled or JS-only page). Runs a local Delphi WebView2 browser exe (UncensoredClaude.exe) that fetches the page outside Claude Code's network and writes its visible text to a file you then Read. Use when WebFetch returns "unable to fetch from <host>", when you need a reddit.com / old.reddit.com page, or the user says "fetch this with the browser tool", "use uncensored claude", "read this blocked page".
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# light-web-UncensoredFetch — read a page WebFetch won't

`UncensoredClaude.exe` drives a real WebView2 browser on this PC, renders one URL, and writes the page's
visible text to a file. It runs OUTSIDE Claude Code's network, so WebFetch's host denylist never applies.

Exe: `C:\Projects\Projects AI\Uncensored Claude\src\UncensoredClaude.exe` (Win64).

## READ THIS FIRST — the one reason it "doesn't work"

The exe is a **GUI-subsystem** app. That changes how you must launch it:

- **Bash tool (recommended): a direct call BLOCKS until the exe exits.** This is the reliable way.
- **PowerShell tool: a direct call `& exe ...` returns INSTANTLY, before the page is fetched.** If you then
  Read the file you get "file not found" or stale content and conclude it failed. It did not — you read too
  early. In PowerShell you MUST use `Start-Process -Wait`.

Verified 2026-07-24: in PowerShell the output file did not exist until ~4 s after `&` returned.

## The command (use the Bash tool)

Quote BOTH paths — the exe path and the output path contain spaces. Use forward slashes or escaped
backslashes; an unquoted path with a space is parsed as extra arguments and fails with exit 1.

```bash
"/c/Projects/Projects AI/Uncensored Claude/src/UncensoredClaude.exe" "<url>" "C:/AI/ClaudeCode-Temp/page.txt"
echo "exit=$?"
```

Then `Read` `C:\AI\ClaudeCode-Temp\page.txt`.

**Smoke test it first if unsure it is built/working:**
```bash
"/c/Projects/Projects AI/Uncensored Claude/src/UncensoredClaude.exe" "https://example.com" "C:/AI/ClaudeCode-Temp/smoke.txt"; echo "exit=$?"
```
Expect `exit=0` and a file containing "Example Domain".

### PowerShell variant (only if you cannot use Bash)
```powershell
$exe='C:\Projects\Projects AI\Uncensored Claude\src\UncensoredClaude.exe'
$p=Start-Process $exe -ArgumentList '"<url>"','"C:\AI\ClaudeCode-Temp\page.txt"' -Wait -PassThru
"exit=$($p.ExitCode)"
```

## Did it work?

- **Exit 0** → trust the file, it holds the page text.
- **Any non-zero exit** → the file still exists and its first line is `[UncensoredClaude] <reason>`. Read it.

| Exit | Meaning | What to do |
|---|---|---|
| 0 | OK | Read the file. |
| 1 | Bad command line | You almost certainly didn't quote a path with spaces. |
| 2 | Navigation failed | URL wrong/offline. The file names the WebErrorStatus. |
| 3 | Empty | Page had no text. Retry with `--raw`, or `--wait 4000` for a slow SPA. |
| 4 | Timeout | Raise `--timeout` (default 30000 ms). |
| 5 | Challenge / login wall | Run the SAME command once with `--visible`, solve it by hand; the session persists, then retry without it. |
| 6 | Browser failed to start | WebView2 runtime problem. Not something to retry blindly — tell the user. |

## Switches

Append after the two paths:

- `--max-chars <n>` — cap the output and append a truncation marker. Use this to avoid flooding context on
  big threads, e.g. `--max-chars 6000`.
- `--raw` — skip the text filter (default filtering strips nav/sidebar/footer chrome). Use if the filtered
  result looks suspiciously short.
- `--selector "<css>"` — read only one region, e.g. `--selector "article"`.
- `--wait <ms>` — extra settle time for slow client-rendered pages (default 1200).
- `--timeout <ms>` — whole-job limit (default 30000).
- `--visible` — show the browser window (for a one-time manual login or to clear a challenge).
- `--no-rewrite` — by default `www.reddit.com` URLs are rewritten to `old.reddit.com` (lighter, comments in
  the HTML). This disables that. Note: `old.reddit.com` truncates very deep comment trees with a
  "load more comments" line — use `--no-rewrite` to read the full `www.reddit.com` SPA when the tail matters.

## Notes

- The output file is ALWAYS written, even on failure, so your Read never fails on a missing file.
- Full project docs: `C:\Projects\Projects AI\Uncensored Claude\CLAUDE.md`.
- Build only via the `light-compiler` agent; engine unit is `C:\Projects\LightSaber\FrameVCL\LightVcl.Internet.Browser.pas`.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
