---
name: light-md-Coherent
description: "Say the last answer again in plain, short English — the jargon-stripped version, an N-point version, or an explanation of just the part that did not land. Use when the user says \"in plain English\", \"coherent\", \"I do not understand\", \"I have no clue\", \"what does that mean\", \"rephrase that\", \"too long\", \"shorter\", \"TL;DR\", \"give me 3 points\", \"wait, what?\", \"short answer\". Rewrites what was ALREADY said — it never re-runs the analysis and never changes the facts. Also works on a Markdown file or block the user names."
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-md-Coherent — say it again, in plain words

The last answer was correct but hard to read: too long, too abstract, or full of words from someone else's field. This skill re-says it. **It is a translation of the previous answer, not a second attempt at it.**

If you catch yourself re-reading a file, re-running a tool, or re-thinking the problem — stop. That is not this skill.

**This skill cannot stay switched on, and no wording inside this file can make it stay switched on.** Claude Code loads the body of a `SKILL.md` only at the moment the skill runs; nothing re-reads it afterwards, so a line saying "remain active" would drift backwards with the rest of the text and stop having force. A standing voice lives in an output style instead — a file in `c:\Users\<you>\.claude\output-styles\`, switched on by `"outputStyle"` in `c:\Users\<you>\.claude\settings.json`. Its text goes into the system prompt and gets re-announced through the whole session, which is what makes it stick. If someone asks why this skill "does not stick", that is the answer: check whether an output style is set, and do not answer from memory.

**This is a cheap operation. Do not spend deep reasoning on it.** The thinking was already done in the message being rewritten; all that is left is choosing shorter words. No effort pin is set on purpose — a frontmatter pin binds only when the slash command is typed, and this skill is mostly reached through plain phrases like "say that simply". This line works on both paths.

## Modes — picked by the argument

| Argument | Mode | Output |
| --- | --- | --- |
| *(none)* | **Plain** | The same answer, plain words, short sentences. Same coverage, fewer syllables. |
| a number, e.g. `3` | **Points** | Exactly N numbered points, most important first. Nothing else — no intro, no closing. Never pad: if the target message holds fewer than N real points, give the ones that exist and say how many there were. |
| a phrase or question, e.g. `what is a DFM binding?` or `the part about the mutex` — or a bare *"I have no clue"* that names no part | **Zoom** | The missing fact first, in plain words, then that part again. Ignore the rest of the answer. When no part is named, you pick it: the one that needed knowledge the reader does not have. |
| a file path, or `this file` | **File** | Same rewrite, applied to that Markdown file (or the section named). Edit in place. |

**Diagnose before you rewrite. One question: did the message fail because of the words, or because of a missing fact?** Words → Plain. Missing fact → Zoom, and supply the fact. *"Too long"*, *"shorter"* and *"in plain English"* are the words. *"I do not understand"* and *"I have no clue"* are almost always the missing fact, and shorter words will not fix them — they make it worse, because the fact gets shorter too.

No argument and the previous answer was already short → still answer in Plain mode. Do not reply "it was already clear."

## The target

Default target is **the last assistant message**. Not the whole conversation, not the task — that one message.

If the last message was a tool result or a subagent report, the target is that report. Agent reports are the usual reason this skill gets called: a subagent inherits the CLAUDE.md rules but **not** the main session's output style, so whatever voice the main session was set to does not reach it.

**If the target message is no longer in context** — the conversation was summarized, or the report was written to a file instead of shown — do not invent a restatement. Say so in one line and ask which part to re-say, or read the file if one was named. Rule 1 forbids re-deriving; it does not license guessing.

File mode overlaps with `/light-md-DelphiIdiom`. Split: use **this** skill on a file written in the current session, to make it readable. Use `/light-md-DelphiIdiom` for a vocabulary sweep across a project's documentation.

## Hard rules

1. **Rewrite, never re-derive.** Every claim in the plain version must already exist in the target message. No new analysis, no new files read, no new conclusions. Zero tool calls in Plain, Points and Zoom mode.
2. **Facts are carried verbatim.** Numbers, versions, file paths, unit and class names, procedure signatures, `[UNVERIFIED]` markers, and every risk or warning move across **unchanged**. Simplify the words. Never simplify the facts. Dropping a caveat because it "reads like hedging" is the one failure this skill must not have.
3. **Keep Delphi words. Kill imported words.** Delphi and RTL vocabulary is not jargon here — it is the correct vocabulary, and `c:\Users\<you>\.claude\CLAUDE.md` requires it.
   - **Keep as-is:** `procedure`, `record`, `RTTI`, `try..finally`, `interface section`, `DFM`, `FMX`, `VCL`, `TThread`, `madExcept`, `LightSaber`, product names, real API names.
   - **Kill on sight:** `leverage` → use · `surface` (as a verb) → show · `orchestrate` → run · `non-trivial` → hard · `semantics` → meaning · `primitive` → building block · `canonical` → standard · `footgun` → easy to get wrong · `idiomatic` → the normal way · `robust` → say what actually survives what. Plus every foreign-stack word already banned in CLAUDE.md (`void`, `lambda`, `throw`, `module`, `header file`).
   - **A term with no plain equivalent** stays, but gets a definition in parentheses on first use — six words, no more.
4. **Assume he shares no context with you. Then put the facts back.**
   ELI5 is half right, and the half it gets right is the half that matters. Corrected 2026-08-23 after Gabriel pushed back with evidence: *"in some places you forget to explain stuff. you talk a lot and you make references to other things that you never explain (files, issues, paragraph 12, other things that you said 1 hour ago). I have seen that ELI5 give good results."* He is right; the earlier version of this rule was wrong.
   - **Keep from ELI5: assume zero shared context.** Name every file with its full path. Explain every term where it first appears. **Never point at something you have not just said** - not "the companion chapter", not "that table", not "the second issue", not "as I mentioned earlier", not "rule 8 of that skill". Each of those is a hole only you can fill, and no amount of simpler vocabulary repairs it. This is the real failure mode, not word choice.
   - **Every pronoun needs a visible owner.** Before you write "it", "this", "that", "they", "these" or "the former", check that the noun it stands for is in the same sentence or the one immediately before. If it sits further back, or if two nouns in the neighbourhood could both fit, **write the noun instead of the pronoun**. It costs three words. Getting it wrong costs Gabriel the whole paragraph, because a sentence with a dangling pronoun still reads perfectly - the hole only appears when he tries to act on it.
     Worst case, and the most common: **"this" or "that" standing for a whole previous paragraph** rather than for a noun. There is nothing to point at. Name the thing: not "this is why it fails" but "the missing `keep-coding-instructions` line is why it fails".
     Real example, 2026-08-23. A quote went into a book chapter beginning *"Claude Code kept calling it an Application Repository"*. Correct English, and unreadable - the thing being named was never introduced. The fix was one sentence of setup before the quote, naming the list of programs the word referred to.
   - **Reject from ELI5: simplifying the facts.** Numbers, versions, file paths, real API names (`LRESULT`, `TThread`, `dbmRequested`) and every warning stay exactly as they were. Simpler words, never simpler facts.
   - Register: a strong engineer whose second language is English. Not a child.
   Aim at ASD-STE100 Simplified Technical English: one idea per sentence, active voice, short sentences, one meaning per word, no stacked nouns. Treat it as a direction, not a specification — the 900-word approved dictionary is not something a model can actually enforce.

5. **Lead with the answer.** First sentence is the conclusion. Then why. Then the caveat. Never build up to it.
6. **No meta.** Do not say what you are about to do, do not compare the two versions, do not apologise for the first one. Just the plain version.
7. **If the plain version exposes a hole, say so — do not patch it silently.** Writing something in simple words sometimes shows the original claim was thin. Then add exactly one line at the end: `Restating this exposed a gap: <what>.` Never silently produce a *different* answer, because then the user cannot tell which of the two to trust.
8. **A question needs its premise, not a shorter word.** Rules 1-7 re-say something the reader has already read, so they assume shared ground. A question has none — the reader was not there for the discovery, so the fault is never the wording, it is the missing premise. Give the ONE fact the decision rests on, in plain words, then the question, then your recommendation. **The test: if answering needs him to already know a type, a flag, an enumeration value, an RTL detail, or anything you learned in the last hour, the question is not ready.** This is rule 3's six-word definition where it matters most and where it is easiest to skip — a term stops feeling like jargon to you the moment you understand it. Same test for `AskUserQuestion`, where it is harder to pass: the options have no room for background, so the background goes in the question text.

## Length

- **Plain:** at most half the target message, and never over whatever chat ceiling your output style sets. With no output style in force, take about 15 lines as the ceiling.
- **Points:** exactly N lines, one sentence each. N points means N lines, not N paragraphs.
- **Zoom:** at most 8 lines.
- **File:** no ceiling — files stay as long as the content needs. The chat cap is for chat.

**When the ceiling and rule 2 collide, rule 2 wins.** A long report with many caveats cannot always be halved without losing a fact. Then keep every fact, go over the ceiling, and say in one line that the plain version is longer than usual — or offer Points mode instead. Never buy brevity with a dropped caveat.

## Cut / keep

**Cut:** restating what the user just said · "it is worth noting that" · lists of files touched · headings over three-sentence sections · both sides of a trade-off that is already decided · every adjective that does not change a decision.

**Keep:** the conclusion · numbers and paths · what the user must do next · anything that changes a decision · anything unverified, still marked unverified.

## Example — re-saying

Target message:

> The root cause is a Win64 pointer-truncation issue: `SendMessage` returns an `LRESULT`, which is 64-bit on Win64, and it is being assigned into an `Integer`, so the upper 32 bits of the returned handle are discarded. This is non-trivial to spot because the code is correct under Win32.

Plain mode:

> On Win64, `SendMessage` gives back an `LRESULT`, which is 64 bits wide. The code stores it in an `Integer`, which holds only 32 bits, so the top 32 bits of the handle are thrown away. The same line is correct on Win32, which is why nobody saw it.

Every fact survived: the API name `LRESULT` stayed (rule 3 keeps real API names), and "upper 32 bits" stayed a number instead of becoming "half" (rule 2 keeps numbers). Only `non-trivial to spot` and `pointer-truncation issue` were traded for plain words. Nothing new was added.

## Example — asking (rule 8)

A bad question fails worse than a bad answer: the reader cannot answer it at all, so the work stops. Real case, 2026-08-22:

> **Should `DoubleBuffer` opt buttons in via `dbmRequested`?** I left it alone — it would change how buttons paint in every app that calls it. *I say leave it.*

Reply: *"I have no clue what you are talking about."* Correct reply. `dbmRequested` was never explained, and the fact the whole decision rests on was never given at all.

> Most controls double-buffer as soon as you set `DoubleBuffered := True`. A `TButton` does not — it also needs a second property, `DoubleBufferedMode`, set to `dbmRequested` (the value meaning "buffer me"), and it never gets it. So our `DoubleBuffer` leaves every button unbuffered. Should it switch buttons on as well? That would change how buttons paint in every app that calls it. **I say no.** (`Vcl.StdCtrls.pas:5750` requires both; `Vcl.Controls.pas:13891` needs only one. `TBitBtn` already opts in — `Vcl.Buttons.pas:301`.)

Same decision, same recommendation, nothing to know in advance. The premise came first, the question second, the recommendation last — and the one unavoidable term got its six words.

## Why this lives in a skill, and where the standing voice really lives

A skill cannot hold a voice open. Claude Code loads the body of a `SKILL.md` at the moment the skill runs and never re-reads it, so a line saying "stay active" drifts backwards with the rest of the text and stops having force. What does stay open is an output style: Claude Code puts its text into the system prompt and re-announces it after tool results all session long. Write one into `c:\Users\<you>\.claude\output-styles\` and switch it on with `"outputStyle": "<its name>"` in `c:\Users\<you>\.claude\settings.json`.

This skill still exists because a style reaches only the main conversation. A subagent runs its own system prompt and never receives one, so a `light-review` or `light-bug` report is exactly the wall of text a style cannot shorten — and that report is what this skill is usually pointed at.

**One trap worth knowing before you write an output style.** A custom style drops Claude Code's
built-in software-engineering instructions unless the file sets `keep-coding-instructions: true`.
It is easy to miss and expensive to debug. Placement, in-session reminders and that key are
documented at https://code.claude.com/docs/en/output-styles.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
