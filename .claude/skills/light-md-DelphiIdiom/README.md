# light-md-DelphiIdiom

Fix Delphi vocabulary and documentation clarity in Markdown files. The same rules apply to ALL Delphi-related prose Claude writes — plans, design notes, code reviews, commit messages, conversational answers — not only MD file edits.

## What this is

A skill + agent pair that catches non-Delphi terminology and confused-Delphi-prose in MD files for Delphi projects. Three failure modes covered:

- **Word-level swaps** — `null` → `nil`, `enum` → `enumeration`, `lambda` → `anonymous method`, `try/catch` → `try/except`, `module` → `unit`. Section A of `vocabulary.md`.
- **Foreign metaphors** — borrowing a concept from another ecosystem when Delphi already has a name for it. Examples: calling a descendant unit a "sidecar" or "override file" (Rust/JS framing); calling someone else's class "the library" and yours "the extension" (npm/PyPI framing). The Delphi word is `descendant unit` / `descendant class` — TfrmAboutOrinoco = class(TfrmAboutApp) is how this has always worked. See the foreign-metaphors section of `writing-good-md.md`.
- **Confused prose** — vague pronouns, abstract verbose sentences, generic nouns where a named Delphi identifier belongs. See `writing-good-md.md`.

## Layout

| File                                           | Purpose                                                                            |
| ---------------------------------------------- | ---------------------------------------------------------------------------------- |
| `SKILL.md`                                     | Thin launcher. Parses args, resolves targets, hands off to the agent.              |
| `references/vocabulary.md`                     | Word-level rules. Section A (always replace), B (judge from context), C (correct). |
| `references/writing-good-md.md`                | Sentence-level rules. Anti-patterns + style invariants + high-bar rule.            |
| `c:\Users\trei\.claude\agents\light-md-DelphiIdiom.md`    | The agent itself. Two-pass per file (vocab → clarity).                             |

## How to use it

- `/light-md-DelphiIdiom` — fix every MD file touched in the current task.
- `/light-md-DelphiIdiom <file.md>` — fix one specific file.
- `/light-md-DelphiIdiom <glob>` — fix every match.

PAS files are NOT touched by default. If you specifically ask ("clean up the comments in `Foo.pas`"), the agent will operate on PAS comments only.

## How it works

1. Skill resolves target files.
2. Skill launches the `light-md-DelphiIdiom` agent with the list.
3. Agent reads `vocabulary.md` and `writing-good-md.md`.
4. For each file:
   - Read whole.
   - Pass 1: apply vocabulary rules (Section A always, Section B from context).
   - Pass 2: apply clarity rules. Strict high-bar: rewrite must be **shorter AND more specific**, must name a specific Delphi identifier, must preserve voice. If any clause fails → skip silently.
   - When the antecedent is unclear ("the destructor" — whose?): re-read MD context, then read linked PAS files, then grep the project. Only skip if exhausted.
5. Agent returns a diff-first report.

## Write-time vs fix-time

`writing-good-md.md` is loaded **both** when retrofitting existing docs (via this skill) **and** when writing new Delphi-related prose (via a one-line directive in the global `c:\Users\trei\.claude\CLAUDE.md`). The agent / Claude is expected to print `--!SLIM MD!--` in the final summary to prove it read the file at write-time.

**Scope of the write-time rule:** ALL Delphi-related prose, not only `*.md` files. Plans, design notes, code reviews, commit messages, and conversational answers about Delphi code all count. The fix-time `/light-md-DelphiIdiom` skill only edits MD files — concept-level violations in conversational prose are caught by Claude reading `writing-good-md.md` up-front, not by post-hoc scanning.

Goal: stop writing bad Delphi prose then fixing it later. Write it correctly the first time. The fix-time path exists for legacy docs.

## Extending the dictionary

When a new term needs a decision: add it to `vocabulary.md` Section D (open questions). Resolve via conversation. Move to A, B, or C. Update the Sources section if a new citation is involved.

Do NOT edit `SKILL.md` unless the skill's *behaviour* itself needs to change.
