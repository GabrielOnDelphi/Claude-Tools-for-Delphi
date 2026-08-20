---
name: light-md-Coherent
description: "Say the last answer again in plain, short English — the jargon-stripped version, an N-point version, or an explanation of just the part that did not land. Use when the user types \"/light-md-Coherent\", or says \"in plain English\", \"coherent\", \"I do not understand\", \"what does that mean\", \"rephrase that\", \"too long\", \"shorter\", \"TL;DR\", \"give me 3 points\", \"wait, what?\", \"short answer\". Rewrites what was ALREADY said — it never re-runs the analysis and never changes the facts. Also works on a Markdown file or block the user names."
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-md-Coherent — say it again, in plain words

The last answer was correct but hard to read: too long, too abstract, or full of words from someone else's field. This skill re-says it. **It is a translation of the previous answer, not a second attempt at it.**

If you catch yourself re-reading a file, re-running a tool, or re-thinking the problem — stop. That is not this skill.

**This is a cheap operation. Do not spend deep reasoning on it.** The thinking was already done in the message being rewritten; all that is left is choosing shorter words. No effort pin is set on purpose — a frontmatter pin binds only when the slash command is typed, and this skill is mostly reached through plain phrases like "say that simply". This line works on both paths.

## Modes — picked by the argument

| Argument | Mode | Output |
| --- | --- | --- |
| *(none)* | **Plain** | The same answer, plain words, short sentences. Same coverage, fewer syllables. |
| a number, e.g. `3` | **Points** | Exactly N numbered points, most important first. Nothing else — no intro, no closing. Never pad: if the target message holds fewer than N real points, give the ones that exist and say how many there were. |
| a phrase or question, e.g. `what is a DFM binding?` or `the part about the mutex` | **Zoom** | Explain only that part, and give the missing context that made it land wrong. Ignore the rest of the answer. |
| a file path, or `this file` | **File** | Same rewrite, applied to that Markdown file (or the section named). Edit in place. |

No argument and the previous answer was already short → still answer in Plain mode. Do not reply "it was already clear."

## The target

Default target is **the last assistant message**. Not the whole conversation, not the task — that one message.

If the last message was a tool result or a subagent report, the target is that report. Agent reports are the usual reason this skill gets called: a subagent inherits the CLAUDE.md rules but **not** the main session's output style, so whatever voice the main session was set to does not reach it.

**If the target message is no longer in context** — the conversation was summarized, or the report was written to a file instead of shown — do not invent a restatement. Say so in one line and ask which part to re-say, or read the file if one was named. Rule 1 forbids re-deriving; it does not license guessing.

File mode overlaps with `/light-md-DelphiIdiom`. Split: use **this** skill on a file written in the current session, to make it readable. Use `/light-md-DelphiIdiom` for a vocabulary sweep across a project's documentation.

## Hard rules

1. **Rewrite, never re-derive.** Every claim in the plain version must already exist in the target message. No new analysis, no new files read, no new conclusions. Zero tool calls in Plain, Points and Zoom mode.
2. **Facts are carried verbatim.** Numbers, versions, file paths, unit and class names, procedure signatures, `[UNVERIFIED]` markers, and every risk or warning move across **unchanged**. Simplify the words. Never simplify the facts. Dropping a caveat because it "reads like hedging" is the one failure this skill must not have.
3. **Keep Delphi words. Kill imported words.** Delphi and RTL vocabulary is not jargon here — it is the correct vocabulary, and `~\.claude\CLAUDE.md` requires it.
   - **Keep as-is:** `procedure`, `record`, `RTTI`, `try..finally`, `interface section`, `DFM`, `FMX`, `VCL`, `TThread`, `madExcept`, `LightSaber`, product names, real API names.
   - **Kill on sight:** `leverage` → use · `surface` (as a verb) → show · `orchestrate` → run · `non-trivial` → hard · `semantics` → meaning · `primitive` → building block · `canonical` → standard · `footgun` → easy to get wrong · `idiomatic` → the normal way · `robust` → say what actually survives what. Plus every foreign-stack word already banned in CLAUDE.md (`void`, `lambda`, `throw`, `module`, `header file`).
   - **A term with no plain equivalent** stays, but gets a definition in parentheses on first use — six words, no more.
4. **Write for a strong engineer whose second language is English.** Not for a child. ELI5 is the wrong dial: it strips precision Gabriel needs and reads as condescending. The dial is *"explain it to a good developer who does not speak this sub-field's dialect."*
   Aim at ASD-STE100 Simplified Technical English: one idea per sentence, active voice, short sentences, one meaning per word, no stacked nouns. Treat it as a direction, not a specification — the 900-word approved dictionary is not something a model can actually enforce.
5. **Lead with the answer.** First sentence is the conclusion. Then why. Then the caveat. Never build up to it.
6. **No meta.** Do not say what you are about to do, do not compare the two versions, do not apologise for the first one. Just the plain version.
7. **If the plain version exposes a hole, say so — do not patch it silently.** Writing something in simple words sometimes shows the original claim was thin. Then add exactly one line at the end: `Restating this exposed a gap: <what>.` Never silently produce a *different* answer, because then the user cannot tell which of the two to trust.

## Length

- **Plain:** at most half the target message. Hard ceiling ~15 lines / ~150 words, same as every chat answer.
- **Points:** exactly N lines, one sentence each. N points means N lines, not N paragraphs.
- **Zoom:** at most 8 lines.
- **File:** no ceiling — files stay as long as the content needs. The chat cap is for chat.

**When the ceiling and rule 2 collide, rule 2 wins.** A long report with many caveats cannot always be halved without losing a fact. Then keep every fact, go over the ceiling, and say in one line that the plain version is longer than usual — or offer Points mode instead. Never buy brevity with a dropped caveat.

## Cut / keep

**Cut:** restating what the user just said · "it is worth noting that" · lists of files touched · headings over three-sentence sections · both sides of a trade-off that is already decided · every adjective that does not change a decision.

**Keep:** the conclusion · numbers and paths · what the user must do next · anything that changes a decision · anything unverified, still marked unverified.

## Example

Target message:

> The root cause is a Win64 pointer-truncation issue: `SendMessage` returns an `LRESULT`, which is 64-bit on Win64, and it is being assigned into an `Integer`, so the upper 32 bits of the returned handle are discarded. This is non-trivial to spot because the code is correct under Win32.

Plain mode:

> On Win64, `SendMessage` gives back an `LRESULT`, which is 64 bits wide. The code stores it in an `Integer`, which holds only 32 bits, so the top 32 bits of the handle are thrown away. The same line is correct on Win32, which is why nobody saw it.

Every fact survived: the API name `LRESULT` stayed (rule 3 keeps real API names), and "upper 32 bits" stayed a number instead of becoming "half" (rule 2 keeps numbers). Only `non-trivial to spot` and `pointer-truncation issue` were traded for plain words. Nothing new was added.

## Why this is a skill and not an output style

The strongest place for a *permanent* voice rule is a custom **output style** — it goes into the system prompt, and Claude Code keeps reminding itself of it during the session, while `CLAUDE.md` is injected once at the top. Anthropic's own documented advice points the same way: effort does not reliably shorten the visible answer, so length has to be prompted for explicitly.

It is the wrong home for *this* rule, for three reasons:

- Long answers are sometimes needed — a design document, a review report, a book chapter. A permanent "be short" rule fights those.
- A custom output style drops Claude Code's built-in software-engineering instructions unless the file sets `keep-coding-instructions: true`. Easy to miss, expensive to debug.
- Output styles apply to the main conversation only. A subagent runs its own system prompt, so a style would not shorten a single `light-review` or `light-bug` report — which is where most of the wall of text actually comes from.

A skill costs nothing until it is invoked, and it works on an agent report just as well as on a chat answer.

## Sources

- Opus 5 answers longer than earlier models, and lowering the effort does NOT reliably shorten them — length must be asked for in words: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5
- Output styles — placement, in-session reminders, `keep-coding-instructions` default `false`, subagents excluded, `/output-style` removed in v2.1.91 (use `/config`): https://code.claude.com/docs/en/output-styles
- ASD-STE100 Simplified Technical English — 53 writing rules, about 900 approved words, edition of January 2025: https://www.asd-ste100.org/about_STE.html
- Origin of the idea: "Opus 5 is driving people nuts. Anthropic gave the fix" — https://www.youtube.com/watch?v=HH6QqWyXJu8 (the `/bro`, `wait, what?` and `/quick` skills shown there are merged into the three modes above).

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*
