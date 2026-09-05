---
name: light-web-UncensoredFetch
effort: low
description: Read ONE web page that Claude Code's built-in WebFetch refuses (the whole reddit.com domain is on WebFetch's denylist; also any Cloudflare-walled or JS-only page). Runs a local Delphi WebView2 browser exe (UncensoredClaude.exe) that fetches the page outside Claude Code's network and writes its visible text to a file you then Read. Use when WebFetch returns "unable to fetch from <host>", when you need a reddit.com / old.reddit.com page, or the user says "fetch this with the browser tool", "use uncensored claude", "read this blocked page".
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# light-web-UncensoredFetch — read a page WebFetch won't

`UncensoredClaude.exe` drives a real WebView2 browser on this PC, renders one URL, and writes the page's
visible text to a file. It runs OUTSIDE Claude Code's network, so WebFetch's host denylist never applies.

Exe: `UncensoredClaude.exe` (Win64). It is a small Delphi WebView2 host, not published — build your own
or point this skill at any equivalent tool that takes a URL and writes the rendered text to a file.
Set its full path in the commands below before using the skill.

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
"<path to your UncensoredClaude.exe>" "<url>" "C:/AI/ClaudeCode-Temp/page.txt"
echo "exit=$?"
```

Then `Read` `C:\AI\ClaudeCode-Temp\page.txt`.

**Smoke test it first if unsure it is built/working:**
```bash
"<path to your UncensoredClaude.exe>" "https://example.com" "C:/AI/ClaudeCode-Temp/smoke.txt"; echo "exit=$?"
```
Expect `exit=0` and a file containing "Example Domain".

### PowerShell variant (only if you cannot use Bash)
```powershell
$exe='<path to your UncensoredClaude.exe>'
$p=Start-Process $exe -ArgumentList '"<url>"','"C:\AI\ClaudeCode-Temp\page.txt"' -Wait -PassThru
"exit=$($p.ExitCode)"
```

## Did it work?

- **Exit 0** → trust the file, it holds the page text.
- **Any non-zero exit** → the file still exists and its first line is `[UncensoredClaude] <reason>`. Read it.
- **Exit 1 AND no file at all** → your command line did not give the exe two positional arguments, so it had nowhere to write. Almost always an unquoted path with a space: the reason file then lands at the FIRST FRAGMENT of that path instead. Measured 2026-08-09 — an unquoted `...\scratchpad\my out.txt` created a file called `my` and nothing at the intended path. Fix the quoting and re-run.

| Exit | Meaning | What to do |
|---|---|---|
| 0 | OK | Read the file. |
| 1 | Bad command line | You almost certainly didn't quote a path with spaces. |
| 2 | Navigation failed | URL wrong/offline. The file names the WebErrorStatus. |
| 3 | Empty | Page had no text. Retry with `--raw`, or `--wait 4000` for a slow SPA. |
| 4 | Timeout | Raise `--timeout` (default 30000 ms). |
| 5 | Challenge / login wall | Needs a human. Do NOT just add `--visible` to the same command — see "Manual login" below. The session then persists and the plain command works. |
| 6 | Browser failed to start | WebView2 runtime problem. Not something to retry blindly — tell the user. |

## Switches

Append after the two paths:

- `--max-chars <n>` — cap the output and append a truncation marker. Use this to avoid flooding context on
  big threads, e.g. `--max-chars 6000`.
- `--raw` — skip the text filter (default filtering strips nav/sidebar/footer chrome). Use if the filtered
  result looks suspiciously short.
- `--selector "<css>"` — read only one region, e.g. `--selector "article"`.
- `--wait <ms>` — extra settle time for slow client-rendered pages (default 1200).
- `--timeout <ms>` — whole-job limit (default 30000). It is forced up to `--wait` + 2000 ms, so a timeout smaller than the settle delay silently becomes bigger than you asked for.
- `--visible` — show the browser window, for a human to log in or clear a challenge. It also raises the DEFAULT `--wait` to 300000 and `--timeout` to 1200000, so the window stays open long enough to be used. See below.
- `--no-rewrite` — by default `www.reddit.com` URLs are rewritten to `old.reddit.com` (lighter, comments in
  the HTML). This disables that. Note: `old.reddit.com` truncates very deep comment trees with a
  "load more comments" line — use `--no-rewrite` to read the full `www.reddit.com` SPA when the tail matters.

## Manual login / clearing a challenge by hand

This needs the user. Do not try to automate it.

```
UncensoredClaude.exe "https://www.reddit.com/login/" "out.txt" --visible --no-rewrite
```

Launch it with PowerShell `Start-Process -Wait` in the BACKGROUND, so you are notified when the window closes instead of blocking on it. Then tell the user: a 1100x700 window has opened at the top-left with NO taskbar button (the app sets `MainFormOnTaskbar = FALSE`) — log in, then **close the window by hand**. That ends the run and flushes the cookies. No output file is written on that run (the extractor never ran) — expected, not a failure. Then re-run the real command with no `--visible`.

Do NOT pass your own `--wait` here unless you want a SHORTER window: an explicit value overrides the generous default and can close the window in the user's face. Before 2026-08-09 `--visible` did not move the defaults, and the window shut ~2 s after the page loaded — that is the bug this replaced.

Verified end to end 2026-08-09 (Opus 5) on Reddit: after the manual login, a later windowless process read `old.reddit.com/message/inbox/` and got the real inbox — A/B'd on the same url with the profile parked aside (exit 2, 151 bytes) versus restored (exit 0, 12 KB). Only cookies with an expiry survive; a session-only cookie dies with the process, like closing a browser.

**To check whether a saved session is still alive, fetch a members-only URL** (`/message/inbox/`), never a preferences page — old.reddit serves an anonymous `/prefs/` that looks identical to the logged-in one. And do not look for `logout` in the output: the DOM strip removes the site's user bar before the text is read. A dead session on a members-only URL shows up as **exit 2, not exit 5** (measured: `WebErrorStatus= 0`, 151 bytes) — no page ever finishes loading, so the challenge detector never gets one to inspect.

## Notes

- The output file is written even on failure — **provided your command line gave the exe two positional arguments.** Verified 2026-08-09: url + outfile + a bad switch → exit 1, and the file holds the reason plus the full usage text. A missing output FOLDER is created for you (verified 2026-07-27). The one case where no file appears is the malformed call in "Did it work?" above.
- Skill re-reviewed 2026-08-09 (Opus 5): the Bash smoke command above was run verbatim → exit 0, the file existed the instant the call returned (that IS the blocking behaviour), and it held "Example Domain". The PowerShell variant, the manual-login flow and every exit-code claim were run live the same day.
- Build only via the `light-compiler` agent; the browser engine is `TWebPageReader` in
  `LightVcl.Internet.Browser.pas`, from LightSaber (https://github.com/GabrielOnDelphi/Delphi-LightSaber).

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
