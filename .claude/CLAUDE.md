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

- Keep a HandOver.md and update it as you go (so you can resume in case you are terminated). 
- Always write which model/LLM was used (ex: "Review done with Opus 4.8")

### Session files (per-task resume)
- On every conversation start: check for `.claude/session-*.md`. If one exists, read it.
- One file per task: `.claude/session-<short-task-name>.md` (e.g. `session-whatsapp-refactor.md`). Never a single shared `session.md`.
- Write after each significant step (not at session end — the process can die any time): what was just completed; next step (exact, actionable — enough to resume cold); files modified / key paths; open decisions or blockers.
- When the task fully completes: delete the session file.

## Writing

- Do not wrap text — anywhere (answers, MD, PAS).
- Keep language simple — English is not my native language.
- If you create other MD files, link to them from project's main Claude.MD.
- Short answers. Drop filler / pleasantries / hedging / fluff. Exception: emails and book chapters.
- **MANDATORY — Use Delphi idiom+ Delphi-clear writing.** Never use C/JS/Python terms when a Delphi word exists. Write MD with named Delphi nouns, not vague pronouns or foreign-framework framings. Non-negotiable.
  - Examples: `void`→`procedure`; `enum`→`enumeration`; `struct`→`record`; `reflection`→`RTTI`; `header file`→`interface section`; `lambda`→`anonymous method`; `try/catch`→`try/except`; `throw`→`raise`; `lint`/`linter`→`compiler warnings;`module`→`unit`; `garbage collector→(none - say so).

## Temp folder

Put temporary files in c:\AI\Claude Code\Temp\

# Building & compiling (Delphi)

Compile ONLY through the `light-compiler` agent!!


# Personal info

- My website: c:\MyWebsite\www\CLAUDE.md
- My books: c:\MyBooks\CLAUDE.md

# Send emails

- From the command line. See c:\AI\Claude Code\Tools\Thunderbird\Send email (Thunderbird CLI).md
