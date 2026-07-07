# Architecture audit — shared principles

Shared by the `light-code-ArchitectureUnit` (unit/file granularity) and `light-code-ArchitectureClass`
(class granularity) agents. Read this at the start of every architecture audit, then apply the
granularity-specific signals in your own agent instructions on top of it. If this file is missing or
unreadable, stop and report — do not audit from memory.

## The mental model — deep vs shallow (Ousterhout)

From Ousterhout, *A Philosophy of Software Design*: a module (a unit, or one level down, a class) =
its **interface** (what a caller must understand to use it) + its **implementation** (what it hides).

- A **deep** module hides a lot of real functionality behind a small interface. This is the goal —
  leave it alone.
- A module is **shallow / mis-shaped** when its interface is large *relative to the functionality it
  provides* — the cost of using it (learning the interface) is close to the benefit it gives back.
- In Delphi the interface is concrete: a unit's `interface` section, or a class's public section.

## Kill the size instinct

Small is NOT the signal. A 90-line unit exposing one `function` that hides real work, or a class with
30 methods that all serve ONE concept, is the IDEAL — leave it alone. The book's warning against
"classitis" (many tiny modules, each adding interface but little function) is exactly the trap a
line-counter falls into. Flag by **coupling / cohesion / interface bloat**, never by absolute
method-count or line-count. Size is at most a tiebreaker between two otherwise-equal candidates.

## Counter-analysis is mandatory

Before recommending any change, argue the OTHER side: *why should this stay as-is?* Apply the
anti-signals in your granularity's instructions. Drop every candidate that survives the challenge as
"keep as-is" — and **state why**, so a later run does not re-flag it. No challenge, no recommendation.

## Prefer non-interface fixes

Favor composition, concrete typing, moving a method, or a shared base class over introducing an `IFoo`.
The Delphi IDE cannot navigate from an interface to its implementers, so interfaces cost real
reading/maintenance time — recommend one only where it clearly pays (a test-substitution /
dependency-injection point) and say why. A Delphi `interface` used for DI so a test can supply a fake
is legitimate — the indirection is the point; do not flag it.

## The LightSaber ↔ app boundary — never cross it

- **LightSaber units/classes are a mature deep-module library.** Skip them unless `--include-lightsaber`
  is passed. That flag only widens what you *analyze* (audit LightSaber's own internals, propose
  LightSaber-internal reshapes); it NEVER authorizes a proposal that moves code or responsibility
  across the LightSaber↔app boundary.
- Reusing existing LightSaber instead of app-reinventing it is fine — that *consumes* the boundary, it
  does not cross it.
- Also skip: **third-party imports** and **test units/classes**.

## Delphi risk flags — flag every one a proposal would touch

These are the expensive mistakes; naming them is the point of the audit. Common to both granularities:

- **Binary / stream compatibility** — does any member participate in `TLightStream` Save/Load or
  another persisted format? A change must not silently alter the on-disk layout or version. Flag it.
- **AppData / INI keys** — would the change move or rename persisted key strings? Flag it.
- **Public API / reuse** — is a member used outside the cluster/class (or by LightSaber)? That
  constrains the change.

Each granularity adds its own flags (unit: none beyond these; class: DFM/FMX bindings, ownership /
free-order). Apply those from your own instructions.

## Rank, and be honest about a null result

- **Rank** survivors by payoff: *(interface/coupling win) ÷ (risk × effort)*. Cap a single proposal's
  blast radius (unit: ≤5 units; class: one class into a few collaborators, not a subsystem rewrite).
- **"Nothing warranted this pass" is a valid, good result.** Do not manufacture findings.
- **Report only — never modify the audited code.** You recommend; the user performs or rejects.

## Large projects — optional fan-out

For a large codebase you MAY fan the read-only mapping out to `Explore` agents (one per subsystem) so
each reads fully instead of sampling, then analyse the merged map yourself. Single-context is fine for
small projects.
