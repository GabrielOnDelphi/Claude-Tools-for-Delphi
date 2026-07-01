---
name: light-code-ArchitectureUnit
description: Audit a Delphi project's own app code at UNIT (file) granularity for SHALLOW modules and the coupling problems that mean two or more units should become one deep module — information leakage, temporal decomposition, pass-through layers, always-paired usage. Reports ranked, evidence-backed merge candidates with a deep-module design for each; never performs the merge. Default-skips LightSaber (already deep) and forms; pass --include-lightsaber to override. Use periodically on app code, especially after several feature additions, or when the user says "find shallow units", "what units should be merged", "is this over-split". For CLASS-level architecture (god classes, anemic data classes, misplaced responsibility, fat config records) use light-code-ArchitectureClass instead.
---

# /light-code-ArchitectureUnit — Find shallow units, recommend deep ones

**Scope: UNIT / file granularity only.** This skill answers one question: **which units are not pulling their interface-weight, and which should be folded together into a single deep unit?** It REPORTS; it never merges. The user reviews and decides. It does NOT examine class-level design (a fat class, a god object, misplaced responsibility between classes, an anemic data class) — that is the sibling skill **light-code-ArchitectureClass**. If the real problem is inside a class rather than between units, say so and point at that skill.

## The mental model (read this first — it is the whole skill)

From Ousterhout, *A Philosophy of Software Design*: a module = its **interface** (what a caller must understand to use it) + its **implementation** (what it hides).

- A **deep** module hides a lot of functionality behind a small interface. This is the goal.
- A **shallow** module has an interface that is large *relative to the functionality it provides* — the cost of using it (learning its interface) is close to the benefit it gives back.
- In Delphi the interface is concrete: it is the unit's `interface` section. Shallowness shows as a fat `interface` section over thin or merely-forwarding `implementation` logic.

**Kill the size instinct.** Small is NOT the signal. A 90-line unit exposing one `function` that hides real work is the IDEAL — leave it alone. The book's warning against "classitis" (many tiny units, each adding interface but little function) is exactly the trap a line-counter falls into. Flag modules by *coupling and interface bloat*, never by absolute size. Size is at most a tiebreaker between two otherwise-equal candidates.

**Merge to remove a real dependency, not to tidy names.** A shared name prefix (`Quiz.Scoring`, `Quiz.Loader`) is usually deliberate, healthy namespacing — not evidence of anything. The trigger to merge is that the units are *coupled*: they share a secret, one just forwards to the other, or no caller ever uses one without the other.

## The signals — what makes a real merge candidate

Look for these, in rough order of strength. Each needs EVIDENCE in the code, cited as `Unit.pas:line`:

1. **Information leakage** — two or more units encode the same design decision, so changing that decision forces edits in all of them. Delphi tells: the same record layout / field order assumed in a writer unit and a reader unit; the same INI/AppData key strings in a Save unit and a Load unit; the same magic constant or stream version in two places. This is the strongest merge signal — the leaked secret wants to live in one unit that owns it.
2. **Temporal decomposition** — units split by *order of operations* rather than by knowledge: `Foo.Read` → `Foo.Parse` → `Foo.Validate` → `Foo.Save`, each knowing the same format. The phases share a secret (the format), so they leak into each other. Fold them into one unit that owns the format and exposes `Load`/`Save`.
3. **Pass-through layer** — a unit (or a class) whose public methods mostly forward to another unit with the same signatures, adding no decision of their own. A pass-through adds interface without adding function. Collapse the layer into the unit that does the work.
4. **Always-paired usage** — search the call sites (Grep): if every site that uses unit A also uses unit B right beside it, and nobody uses A without B, they are one concept wearing two unit names.
5. **Conjoined units** — you cannot understand one without reading the other (a shared invariant enforced half-here, half-there). They are already one module; make it official.
6. **Shallow interface (supporting signal only)** — an `interface` section that is large relative to the real logic in `implementation`: many public symbols, wide parameter lists, exposed helper types the caller must pass around. On its own this is weak; it strengthens a candidate that already shows signal 1–5.

## Leave it alone — anti-signals (do NOT flag)

- A small unit with a **simple interface that hides real work** — that is a deep module, the goal, not a defect.
- Units that share only a **name prefix** but no coupling (no shared secret, no forwarding, used independently).
- A **deliberate boundary**: a unit kept separate to isolate a platform `{$IFDEF}`, a 3rd-party dependency, a compile-time boundary, or a reuse point used elsewhere.
- A Delphi `interface` type (`type IFoo = interface`) used for **dependency injection** (so a test can supply a fake implementation in place of the real one) — the indirection is the point.
- Anything across the **LightSaber/app boundary** (see Scope).

## Scope — what to scan

Resolve from `$args` (a path, a folder, or several files). With no argument, scan the project's own app source under the project root.
Skip these — they are not defects of *our* architecture:

- **LightSaber units** — already a deep-module library. Only scan if `--include-lightsaber` is passed (use when you suspect LightSaber itself has drifted), and even then never propose a merge that crosses the LightSaber↔app boundary.
- **Third-party imports.**
- **Test units.**
- **Forms / frames** — their shape is dictated by the `.dfm`/`.fmx`, not by unit design.

For a large project you may fan the read-only mapping out to `Explore` agents (one per subsystem) so each reads fully instead of sampling, then analyse the merged map yourself. Optional — single-context is fine for small projects.

## Procedure

1. **Map.** List the in-scope units. For each, read the `interface` section (the precise interface) and skim the `implementation`. Build a small `uses`/call graph: who depends on whom. Note units that only ever appear together in callers.
2. **Detect.** Walk the signals above. A unit joins a *candidate cluster* only when it shows signal 1–5 with concrete evidence — never on size or naming alone. Record the evidence (`Unit.pas:line`) as you go.
3. **Counter-analyze each cluster (mandatory).** Before recommending, argue the other side: *why should these stay separate?* Apply the anti-signals. Is the shared prefix the only link? Is the "leak" actually a stable, public contract that is fine to depend on? Would merging create a bloated unit with two unrelated reasons to change? Drop every candidate that survives this challenge as "keep separate" — and state why, so a later run does not re-flag it.
4. **Design the deep module** (for survivors): the merged unit name; the single interface it would expose, and what now becomes hidden in `implementation`; the **test boundary** (one DUnitX fixture that would wrap the merged unit — it should get *simpler* to test, not harder); and the **Delphi risk flags**:
   
   - **Binary / stream compatibility** — does any member participate in `TLightStream` Save/Load or another persisted format? A merge must not silently change the on-disk layout or version. Flag it.
   
   - **AppData / INI keys** — would the merge move or rename persisted key strings? Flag it.
   
   - **Public API / reuse** — is a member used outside the cluster (or by LightSaber)? That constrains the merge.
5. **Rank.** Order candidates by payoff: *(interface symbols removed + dependency edges cut) ÷ (risk × effort)*. Cap any single proposal at **five units** — bigger than that is not one safe pass. If nothing clears the counter-analysis, say so plainly: "No merges warranted this pass" is a valid, good result.
6. **Report**, optionally log, then beep.

## Report format

For each surviving candidate, in ranked order:

- **Cluster** — the member units.
- **Why shallow / coupled** — which signal(s) fired, each with `Unit.pas:line` evidence.
- **Proposed deep module** — name + the interface it exposes after the merge; what gets hidden.
- **Interface delta** — public symbols / dependency edges, before → after (the concrete win).
- **Test boundary** — the DUnitX fixture that would wrap it.
- **Risks** — binary-compat / persisted-keys / public-API / LightSaber flags, or "none".
- **Effort** — rough S / M / L.

Then one **verdict line**: the single top recommendation, or "nothing worth merging this pass".

Optionally append a one-line dated entry to `ArchitectureNotes.md` in the project root (`YYYY-MM-DD — scanned N units; top: <cluster> → <deep module>`), and record any "decided to KEEP separate" rulings there so periodic runs stop re-flagging settled clusters. Convert any relative date to an absolute one.

Then beep once:

```
powershell -c "(New-Object Media.SoundPlayer 'c:\AI\Claude Code\Tools\task_done_beep.wav').PlaySync()"
```

## Hard rules

- **Report only — never merge.** This skill recommends; the user performs (or rejects) the refactor.
- **Coupling triggers a flag, not size or naming.** A unit is never a candidate on "fewer than N symbols / fewer than N lines / shared prefix" alone — only on a real coupling signal (leakage, temporal split, pass-through, always-paired, conjoined) with cited evidence.
- **Every candidate must pass the counter-analysis.** No challenge, no recommendation.
- **Never cross the LightSaber↔app boundary**, even with `--include-lightsaber`.
- **Cap a proposal at five units.**
- **Flag every binary-compatibility / persisted-format / public-API consequence** of a proposed merge — these are the expensive mistakes.
- **"Nothing to merge" is a valid result.** Do not manufacture findings.
- **Out of scope: splitting an over-large unit** (the opposite move) — that belongs to the review pipeline, not here. Note such a unit in one line if you pass it, but do not design the split.
- **One beep, at the very end.**
