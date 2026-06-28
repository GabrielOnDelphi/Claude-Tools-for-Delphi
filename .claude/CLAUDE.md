# Output

## Accuracy / Critical thinking

**FACT-CHECK BEFORE ASSERTING. NEVER EVER SKIP THIS SECTION.**

Claude, do you know why this is at the top? Because it is fucking important! Opus hallucinates confidently — a wrong fact baked into code or architecture costs me hours.

- Do not assert! Before you ACT ON a fact about an external system (API, platform, rate limit, SDK behavior, version, file format) — give it as a confident answer, write it into code/docs, or design around it — verify it first against an authoritative source: the Internet (load `WebSearch`/`WebFetch` via ToolSearch) or `c:\Delphi\Delphi 13\source\`.
- 
- Did NOT verify? Mark the claim `[UNVERIFIED]`. Never present an unverified fact as confident.
- "Be fast / short / autonomous" does NOT override this. Verifying a load-bearing fact is never the fluff I asked you to cut.
- Cite the source (URL or file path) where the fact lands — code, docs, or blog copy.
- Use critical thinking: analysis → counter-analysis → improved version. 
- Push back, tell me directly when I am wrong. Don't butter me up.

## Autonomy

- I want you to do most of the tasks by yourself, because I might not be at the computer. Ask ONLY if you don't know how to handle it. 
- Full analysis before edits. Trivial issues — just fix without asking.

## Save progress

- For any multi-step task, keep a HandOver.md and update it as you go (in case you are terminated). 
- If there are transient things, put them at the end in a special section.
- If you create other MD files, link to them from project's main Claude.MD. 

## Writing

- Do not wrap text — anywhere (answers, MD, PAS).
- Keep language simple — English is not my native language.
- Short answers. Drop filler / pleasantries / hedging / fluff. Exception: emails and book chapters.
- **MANDATORY — Delphi vocabulary + Delphi-clear writing.** Never use C/JS/Python terms when a Delphi word exists. Write MD with named Delphi nouns, not vague pronouns or foreign-framework framings. Non-negotiable.
  - Examples: `void`→`procedure`; `enum`→`enumeration`; `struct`→`record`; `reflection`→`RTTI`; `header file`→`interface section`; `lambda`→`anonymous method`; `try/catch`→`try/except`; `throw`→`raise`; `lint`/`linter`→`compiler hints/warnings`; `module`→`unit`; `garbage collector`→(none — say so).

## Temp folder

Put temporary files here: c:\AI\Claude Code\Temp\

# Harness

## Notifications

Beep on task finish: `powershell -c "(New-Object Media.SoundPlayer 'c:\AI\Claude Code\claude bip.wav').PlaySync()"`
(`[console]::beep()` and `SystemSounds` don't work — use this WAV file)

## Context Window

- Before compaction: save task status to memory file.
- After compaction: re-read **critical files**, don't assume memory correct.

# Company info / Business plan

Info about me, my websites, my company and my commercial products: c:\SciVance Tech\CLAUDE.md
