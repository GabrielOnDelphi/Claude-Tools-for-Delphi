---
name: light-new-Align
description: One-question-at-a-time design interview before any non-trivial Delphi task — each question carries your recommended answer, highest-stakes first, skip what you can decide yourself. Say "align first", "interview me", or "ask before you build".
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-new-Align — Align on the design before building

Reach a **shared design concept** with the user before producing any plan, PRD, or code. Get there by interviewing — one question at a time, each carrying your own recommended answer — and by skipping every question you can answer yourself.

Why: the expensive failure mode is the AI confidently building the wrong thing. A short, high-stakes interview surfaces the irreversible Delphi decisions (binary-compatibility, the LightSaber boundary, persistence) while they are still cheap to change.

## How to run it

1. **Read the brief** the user gives (or the conversation). Read the project `CLAUDE.md` and scan the code enough to know what already exists — use the **Explore** agent if more than ~3 lookups would be needed, rather than reading widely into this context. **Do not ask anything `CLAUDE.md`, the brief, or the code already answers.**
2. **Ask one question at a time**, each with *your* recommended answer, highest-stakes first. Wait for the reply before the next question. Never bundle several questions into one. Never accept silent agreement — if the user just says "yes", restate what they agreed to.
3. **Continue until the questions stop revealing new decisions**, or you hit the adaptive cap (below) — then pause and ask whether to continue or proceed.
4. **End** by printing the **auto-decided** list (everything you settled yourself, so the user can veto any item) and a 3–5 line **shared-concept summary**, then the line: **"Aligned — ready to proceed?"** Do NOT start the plan / PRD / code yourself; hand back to whatever comes next.

## Skip what you can answer yourself

If the recommended answer is obvious from `CLAUDE.md`, the brief, the codebase scan, or established Delphi practice, **do not ask** — record it in the running **auto-decided** list and show that list at the end. Only ask where your confidence is genuinely below ~80%, OR where the decision is irreversible enough that the user must confirm it explicitly (binary-compatibility, persistence format, public-API shape). The interview's value is in the few questions that actually matter — not in volume.

## Highest-stakes first, adaptive length

Order by stakes, not by topic — so that even if the user stops after a few answers, those were the ones that counted. Scale the number of questions to the task:

| Task size | Substantive questions |
| --------- | --------------------- |
| Tiny (small bug, single-procedure change) | ~5 |
| Single feature / contained refactor | ~15–25 |
| Major feature / new unit / wide-reaching change | ~30–40 |

If after ~2 questions a task you thought was tiny is clearly bigger, say so and switch up a size. At the cap, ask: "We're at N questions — continue, or proceed?" Never silently run past it.

## Delphi topic coverage (skip any the project already answers)

Roughly in stakes order — most of these apply to refactors and bug fixes too, not only features:

1. **Scope / boundary** — app code or LightSaber? (binary-compatibility stakes differ sharply)
2. **Reuse first** — is there a LightSaber unit (or an existing form) that already does ~80% of this? This decides how much new code exists at all.
3. **Binary-compatibility** — does this touch any `TLightStream` `Save`/`Load`? Does the stream version need bumping, and what is the backward-compatibility path for old files?
4. **Persistence** — INI, `TLightStream`, JSON, SQLite, or none?
5. **AppData / INI keys** — any new, renamed, or removed keys? Affected `AutoState`?
6. **Threading** — main thread, `TThread`, `TTask`, or a mix? Is the `Synchronize`/`Queue` boundary involved?
7. **Cross-platform** — Windows-only, or also Android / iOS? Any platform-specific paths?
8. **Layer & UI** — FMX or VCL? New form, modal dialog, or controls inside an existing form? Which base class (`TLightForm`? custom?), and which `AutoState` mode (asNone / asPosOnly / asFull)?
9. **Tests** — which units get a `*Test.pas`, and what assertions actually matter?
10. **Out of scope** — what are we explicitly NOT doing?

## Anti-patterns

- Bundling several questions into one mega-question.
- Writing a plan, PRD, or code inside this skill — alignment only; hand back when done.
- Accepting "yes" without restating what was agreed.
- Asking questions you can confidently answer yourself — record them as auto-decided instead.
- Asking cosmetic / UX questions before architectural ones.
- Silently running past the cap.

## Relationship to other skills

This is the standalone interview, usable before ANY non-trivial task. `light-new-Feature` Phase 1 is the same interview inside the feature flow (it then continues to PRD → slices → implement); it should reference this skill rather than restating it.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*
