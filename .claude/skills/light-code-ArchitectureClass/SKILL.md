---
name: light-code-ArchitectureClass
description: Audit a Delphi project's own app code at CLASS granularity for ill-shaped classes — god classes / low cohesion, anemic data classes, misplaced responsibility (feature envy), shared mutable singletons with hand-rolled lifecycles, fat config records, type-erased back-references, and capability-bolted-on-via-Ex-subclass reached by downcast. Unlike the unit-merge skill it INCLUDES forms (the biggest god classes are usually forms). Reports ranked, evidence-backed class-reshaping recommendations (extract-class, move-method, introduce-interface, collapse-wrapper, replace-singleton); never performs the refactor. Use when the user says "is this a god class", "review the class design", "what class should be split", "is this class doing too much", "find anemic classes". For UNIT (file) merge/split decisions use light-code-ArchitectureUnit instead.
---

# /light-code-ArchitectureClass — Find ill-shaped classes, recommend better-shaped ones

**Scope: CLASS granularity.** This skill answers: **which classes carry the wrong shape — too many responsibilities, no responsibility, or a responsibility that belongs elsewhere — and how should they be reshaped?** It REPORTS; it never refactors. The user reviews and decides. It does NOT decide whether two *units* should merge — that is the sibling skill **light-code-ArchitectureUnit**. If the real fix is a file merge/split, say so and point there.

## The mental model (read this first — it is the whole skill)

From Ousterhout, *A Philosophy of Software Design*, applied one level down from the unit: a class = its **public section** (the methods + properties a caller must learn to use it) + what it **hides** (private fields, private logic, invariants).

- A **deep** class hides a lot of real work behind a small, coherent public section. This is the goal — leave it alone.
- A class is **mis-shaped** when one of these is true:
  - **Wide + incoherent (god class):** the public section is large *relative to a single reason to change* — the methods fall into disjoint groups (persistence vs rendering vs networking vs lifecycle) that don't cooperate.
  - **Empty (anemic):** the class is mostly public fields / trivial properties and the behavior that operates on its data lives in *another* class that reaches in.
  - **Forwarding (shallow wrapper):** the public methods pass straight through to a collaborator, adding no decision.
  - **Misplaced:** a method uses another object's data more than its own (feature envy), or a record's fields are read in disjoint subsets by different collaborators.

**Kill the size instinct.** A class with 30 methods that all serve ONE concept is a rich domain entity — DEEP, not a god class. Flag by **cohesion and responsibility**, never by raw method/line count. Size is at most a tiebreaker. (Same discipline as the unit skill: a big cohesive thing is good; many tiny things or one incoherent thing is the smell.)

**Reshape to separate a real responsibility, not to hit a metric.** The trigger is that the class holds *two reasons to change* (extract one out), or *zero* (fold the behavior in), or it forwards everything (collapse it). A class with many cohesive methods serving one job is not a candidate no matter how large.

**The fix is a CLASS refactor**, never a file merge: extract-class, move-method, introduce-interface, collapse-wrapper, replace-mutable-singleton-with-owned-member. If the genuine fix is merging/splitting whole units, defer to **light-code-ArchitectureUnit** — do not duplicate it here.

## The signals — what makes a real candidate

Each needs EVIDENCE in the code, cited as `Unit.pas:line`. Rough order of strength:

1. **God class / low cohesion** — one class with several independent reasons to change. Delphi tells: public methods cluster into disjoint groups (e.g. `Load*/Save*` INI persistence + `Apply*` orchestration + `Show*Settings` UI + `UpdatePreview*` rendering) where one group's methods never call another's, and fields are used by only one cluster. → extract each cluster into its own collaborator class.
2. **Anemic data class** — mostly public fields / trivial getters, with the real behavior in another class that reads it (plain getters, or worse, `as`-downcasts into it). → move the behavior onto the data, OR confirm it's a deliberate DTO/record (anti-signal).
3. **Shared mutable singleton / global state with a hand-rolled lifecycle** — a `class var` or global object manually created, parked, nil-ed, and restored, *especially* when other code captures raw pointers (`^`, aliased fields) into it. Very fragile (use-after-free territory). → owned member, immutable record, or explicit single-owner.
4. **Fat config record / feature envy** — a record/class whose fields are consumed in disjoint subsets by different collaborators (each reaches for "its" slice), or a method that touches another object's data more than its own. → split the record (per-collaborator sub-records / an interface), or move the method to the data it envies.
5. **Type-erased back-reference** — a field declared `TObject` (or a vague base) purely to break a `uses` cycle, then cast back with `as` N times to use it. Defeats compile-time checking. → a shared base class, or a unit restructure (often this is really a *unit-structure* problem in disguise — hand off to **light-code-ArchitectureUnit**). An interface fixes it too but costs implementer-navigation in the IDE — prefer the above (see Hard rules).
6. **Base-typed holder reached by downcast (usually an `Ex` subclass)** — a holder typed as a base `TFoo` whose every use site does `(X as TFooEx)` to reach the added behavior, when that holder is *always* a `TFooEx`. The base is never used as an abstraction; the cast trades a compile-time guarantee for a run-time `EInvalidCast`, and you pay twice — you gave up the base abstraction AND you still name the concrete `TFooEx` at every call. The `Ex`-subclass shape is the common *cause*; the defect is the base-typing-plus-downcast, not the split itself. **Decisive test: does that holder ever hold a plain `TFoo`?** If yes (guarded `if X is TFooEx then`), it is real polymorphism — leave it, or lift the behavior into a virtual method on the base. If it is always a `TFooEx` → fix, in this order: (a) store the concrete `TFooEx` and delete the casts (cheapest; keeps the repeated setup code parked in the parent); (b) composition — the domain class HAS-A a persistence helper; (c) if the casts only exist to break a `uses` cycle, restructure the units (hand to **light-code-ArchitectureUnit**) or add a shared base class in a neutral unit. Put the added behavior on the base only when you own the base.
7. **Shallow wrapper class** — public methods forward 1:1 to a collaborator with no added decision. DISTINGUISH from a legitimate adapter over a *reused* engine or a 3rd-party lib (that indirection is the reuse point — anti-signal).
8. **Long method / parameter bloat (supporting signal only)** — a single method doing several jobs, or a 5+-parameter signature where a record/object fits. Weak alone; it strengthens a god-class case already supported by signal 1–4.

## Leave it alone — anti-signals (do NOT flag)

- A **rich, cohesive domain entity** — many methods that all serve one concept (a `TWallpaper`-style object). Large but cohesive is deep.
- A deliberate **DTO / record / value object** with no behavior by design.
- A **thin adapter over a reused engine or 3rd-party** (e.g. a plugin wrapping a standalone animation engine used by other apps/testers) — the thinness is the reuse boundary.
- A Delphi **interface (`IFoo`) used for dependency injection** so tests can supply a fake — the indirection is the point.
- A **base class with virtual/abstract methods that subclasses genuinely override** — real polymorphism, not a god class.
- **VCL-imposed public section on a form** — the event handlers the `.dfm` assigns are not the form's "design". Judge the form's OWN methods and responsibilities, not the designer-generated plumbing.
- An **`Ex` subclass whose holders store `TFooEx`** (no base-typed downcast) — the split just parks repeated setup code in the parent, or extends a type you don't own. That is a reading aid, not a defect; only base-typed-holder + downcast is the smell.
- A **base that supplies shared persistence/streaming to many genuine subclasses** (TPersistent-style) — DRY inheritance actually reused by real subclasses, not the Ex smell.

## Scope — INCLUDING forms

Resolve from `$args` (a path, a folder, or several files). With no argument, scan the project's own app source classes under the project root — **including form and frame classes**. This is the deliberate difference from light-code-ArchitectureUnit, which skips forms: the biggest god classes in a VCL/FMX app are usually the main form and the settings form. For a form, analyze the class's **own** responsibilities — does `TfrmMain` also do persistence, networking, business rules, file IO? — and recommend extracting the non-UI responsibility into a controller/service class. **Never redesign the `.dfm`/`.fmx` layout**; you move *code*, not controls.

Still skip (not defects of *our* class design):
- **LightSaber** classes (a mature library) are skipped unless `--include-lightsaber` is passed — which makes the skill audit LightSaber's *own internal* class design and propose LightSaber-only reshapes. Either way, no single proposal moves code or responsibility across the LightSaber↔app boundary.
- **Third-party imports.**
- **Test classes.**

For a large project you may fan the read-only mapping out to `Explore` agents (one per subsystem) so each reads fully instead of sampling, then analyse the merged map yourself.

## Procedure

1. **Map classes.** For each in-scope class: its public section (methods + properties), how its fields cluster, the responsibilities it carries, its collaborators, and its place in any inheritance chain. Note which class reads/downcasts into which.
2. **Detect.** Walk the signals. A class joins the candidate list only on signal 1–7 with concrete `Unit.pas:line` evidence — never on size alone. Record the evidence as you go.
3. **Counter-analyze each candidate (mandatory).** Argue the other side first: is this a cohesive rich entity? a deliberate DTO? a legit adapter over a reused engine? real polymorphism? VCL-imposed form plumbing? Drop every candidate that survives the challenge as "keep as-is" — and state why, so a later run does not re-flag it.
4. **Design the better shape** (for survivors): the extracted class(es) / introduced interface; exactly what moves where; the resulting public sections (what each class now exposes and hides); the **test boundary** (does the responsibility become independently testable?); and the **Delphi risk flags**:
   - **Binary / stream compatibility** — does a field you'd move participate in `TLightStream` Save/Load or another persisted format? Moving it must not change the on-disk layout/order. Flag it.
   - **AppData / INI keys** — would the reshape move or rename persisted key strings? Flag it.
   - **DFM/FMX bindings** — if you move a method that the design file assigns to an event (`OnClick`, `OnCreate`), it must stay reachable on the form (or be re-assigned). Flag it.
   - **Ownership / lifetime** — extracting a class changes who creates/frees what. State the new ownership and any `FreeAndNil` order it implies (BioniX has documented free-order AVs).
   - **Public API / reuse** — is a member used outside the class (or by LightSaber)? That constrains the move.
5. **Rank.** Order by payoff: *(responsibilities separated + coupling cut + public section clarified) ÷ (risk × effort)*. Cap a single proposal's blast radius — one class into a small number of collaborators, not a whole-subsystem redesign in one pass. If nothing clears the counter-analysis, say so: "No class reshaping warranted this pass" is a valid, good result.
6. **Report**, optionally log, then beep.

## Report format

For each surviving candidate, in ranked order:

- **Class** — `TName` (`Unit.pas:line`).
- **Shape problem** — which signal(s) fired, each with `Unit.pas:line` evidence.
- **Proposed shape** — the extracted class(es)/interface; what moves out; the resulting public section of each class; what now becomes hidden.
- **Cohesion / coupling delta** — responsibilities-per-class and inbound downcasts/edges, before → after.
- **Test boundary** — the DUnitX fixture(s) that would wrap the reshaped classes; note if testing gets simpler.
- **Risks** — binary-compat / persisted-keys / DFM-binding / ownership / public-API flags, or "none".
- **Effort** — rough S / M / L.

Then one **verdict line**: the single top recommendation, or "nothing worth reshaping this pass".

Optionally append a one-line dated entry to `ClassArchitectureNotes.md` in the project root (`YYYY-MM-DD — scanned N classes; top: <TClass> → <reshape>`), and record any "decided to KEEP as-is" rulings there so periodic runs stop re-flagging settled classes. Convert any relative date to an absolute one.

Then beep once:

```
powershell -c "(New-Object Media.SoundPlayer 'c:\AI\Claude Code\Tools\task_done_beep.wav').PlaySync()"
```

## Hard rules

- **Report only — never refactor.** This skill recommends; the user performs (or rejects).
- **Cohesion / responsibility triggers a flag, never raw size or method-count alone.** A class is never a candidate on "more than N methods / more than N lines" — only on a real shape signal (god/low-cohesion, anemic, mutable-singleton, feature-envy, type-erased back-ref, Ex-downcast, shallow-wrapper) with cited evidence.
- **Every candidate must pass the counter-analysis.** No challenge, no recommendation.
- **INCLUDE forms** — judge a form class's OWN responsibilities; recommend extracting non-UI work into a service/controller. **Never** touch `.dfm`/`.fmx` layout.
- **No proposal moves code or responsibility across the LightSaber↔app boundary** — not even with `--include-lightsaber`. That flag widens what you *analyze* (audit LightSaber internals, propose LightSaber-internal reshapes); it never authorizes a reshape that straddles the boundary. Reusing existing LightSaber instead of app-reinventing it is fine — that consumes the boundary, it does not cross it.
- **Prefer non-interface fixes.** Favor composition, concrete typing, moving a method, or a shared base class over introducing an `IFoo`. The Delphi IDE cannot navigate from an interface to its implementers, so interfaces cost real reading/maintenance time — recommend one only where it clearly pays (a test substitution point / dependency-injection point) and say why.
- **Cap a proposal's blast radius** — one class into a few collaborators, not a subsystem rewrite.
- **Flag every binary-compatibility / persisted-format / DFM-binding / ownership consequence** of a proposed reshape — these are the expensive mistakes.
- **If the real fix is merging/splitting UNITS, hand off to light-code-ArchitectureUnit** — don't duplicate the unit-merge analysis here.
- **"Nothing to reshape" is a valid result.** Do not manufacture findings.
- **One beep, at the very end.**
