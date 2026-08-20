---
name: light-bug-MadShi
description: "Diagnose and fix a Delphi crash report (madExcept .mad) for any registered product (BioniX, ...). Reads the product profile in products.ini, lists the recent .mad attachments across that product's Thunderbird mbox(es), lets the user pick one (or accept the newest), then launches the light-bug-MadShi agent to diagnose, fix, and build (never release). This is the crash-report-specific pipeline behind the general /light-bug skill's Step 0 routing — invoke it directly when you already have a .mad file or Thunderbird crash report in hand. Use when the user says \"/light-bug-MadShi\", \"/light-bug-MadShi bionix\", \"new crash report\", \"check the latest .mad\", or similar."
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-bug-MadShi — Delphi crash-triage pipeline (multi-product)

When the user invokes `/light-bug-MadShi`, do this in order. Be terse. Each step is a single tool call unless noted.

The pipeline is product-driven. Every product is one block in `~\.claude\skills\light-bug-MadShi\products.ini` (mbox list + source paths + fix-log location + memory subfolder). Read that file first — it is the single source of routing facts.

## Step 0 — Resolve the product and the argument

Parse `$args`:

- **A `.mad` path** (an existing file ending `.mad`): skip listing. Decide the product by reading the first ~2 KB of the file and matching its `executable` line against each block's `ExeMatch` in `products.ini`. If a product word is ALSO given, trust that. Go to step 4 with this path.
- **A product word** (`bionix` -> `[BioniX]`; `myproduct` -> `[ExampleProduct]`; match case-insensitively): use that block. Go to step 1.
- **Nothing / unclear**: ask with `AskUserQuestion` which product (one option per block in `products.ini`). Then go to step 1.

Read the chosen block. Keep every field — you will pass them all to the agent in step 4.

## Step 1 — List recent .mad candidates across the product's mbox(es)

Split the block's `Mboxes` on `|`, trim each, and pass them all as one array to the extractor. It merges newest-first and removes duplicates:

```powershell
$mboxes = @('<path1>','<path2>','<path3>')   # from the block's Mboxes field
& '~\.claude\skills\light-bug-MadShi\Tools\extract-mad.ps1' -MboxPath $mboxes -List -OutPrefix '<OutPrefix>'
```

Do NOT add `-ExecutionPolicy Bypass` (the auto-mode classifier blocks it; the script runs without it).

Each stdout line is tab-separated:
`index<TAB>date<TAB>from<TAB>subject<TAB>sizeBytes<TAB>exeVersion<TAB>status<TAB>sourceMbox`
- `status` is `ok`, `stub` (attachment manually deleted), or `invalid` (decode failed / under 1 KB).
- `sourceMbox` is the leaf name of the mbox the report came from.
- Stderr carries progress.

If the script throws or returns no lines, report it and stop. Likely causes: every mbox empty of `.mad`, a renamed Thunderbird profile (path changed), or the mbox locked by Thunderbird.

## Step 2 — Show the candidates and let the user pick

Parse the lines into a list. Use `AskUserQuestion` with up to 4 options:

- **Option 1 (recommended):** "Newest — `<subject>` (v<exeVersion>, <date>)"
- **Option 2 / 3:** the next two candidates.
- **Option 4:** "Show all <N> candidates" — when picked, print the full list as a markdown table and ask for the index.

If only one candidate exists, skip the question and go to step 3 with `-Index 1`. Mark any `stub` candidate clearly ("[stub — attachment deleted]") so the user does not pick it.

## Step 3 — Extract the chosen .mad

Re-run the extractor with the same mbox array and `-Index N`:

```powershell
& '~\.claude\skills\light-bug-MadShi\Tools\extract-mad.ps1' -MboxPath $mboxes -Index <N> -OutPrefix '<OutPrefix>'
```

The last stdout line is the absolute path of the extracted file. Capture it.

## Step 4 — Hand off to the light-bug-MadShi agent

Launch via the `Agent` tool, `subagent_type: "light-bug-MadShi"`, in the **foreground**. The briefing MUST include:

- The product name and its FULL profile block from `products.ini` (every field: `SourceRoot`, `ProjectFile`, `ProjectClaude`, `BugProtocol`, `FixesLog`, `BugFolderRoot`, `ReleaseDir`, `PathRebase`, `MemorySub`).
- The absolute path of the extracted `.mad`.
- A short note of what the user said and which candidate they picked.
- The reminder: "Do not release. Stop before the release step. The user reviews the diff manually."

## Step 5 — Relay the agent's report

When the agent returns:
- Summarize in 3–5 sentences: bug class, root cause, files touched, build result.
- Give the path to the agent's `Analysis.md`.
- State explicitly that **no release was triggered** and what to do next (review the diff, then say "release" to ship).

## Failure modes

- **Extractor throws on -List / -Index.** Surface the exact PowerShell error. Mbox locked by Thunderbird → tell the user to close Thunderbird and retry. Stub picked / index out of range → re-list.
- **Agent stops asking a question.** Forward it to the user verbatim — do NOT answer on their behalf.
- **Agent says "already fixed in current source".** Don't compile or modify anything. Report the duplicate and which Fixes Log entry it matches.

## Notes

- "Do not release" stands until the user says otherwise. Both this skill and the agent respect it.
- Profiles live in `products.ini`. To add a product, add a block there — no skill or agent edit needed.
- The extractor is idempotent: running it twice re-extracts the same `.mad` to a new timestamped file.
- `-Top` defaults to 10. For more candidates, add `-Top 20` (or higher) to the `-List` call.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*
