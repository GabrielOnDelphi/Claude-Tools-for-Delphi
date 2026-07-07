---
name: light-ref-Refactoring
description: Reference catalog of behaviour-preserving Delphi refactorings — Extract Method, Extract Class, Guard Clauses, Named Constants, Replace Conditional with Polymorphism, Introduce Parameter Object (record), Remove with, Rename, Inline Method, and introducing a test seam via a shared base class. Load this when cleaning up smelly code, taming a long method or god class, or planning a safe refactor. Adapted to Gabriel's stack: shared base / concrete typing over interfaces, test-green before and after, compile only via the light-compiler agent. Pairs with /light-code-ArchitectureUnit and /light-code-ArchitectureClass.

---

# Delphi refactoring — reference

Refactoring changes structure, **not behaviour**. The only proof of that is a test that is green before and stays green after. If the code under change has no test, write one first (`/light-review-RedGreen`) — otherwise you are rewriting, not refactoring.

## Safe process

1. Green baseline — the relevant DUnitX tests pass now.
2. One small step at a time — never batch unrelated moves.
3. Compile **only** via the `light-compiler` agent (global CLAUDE.md rule), then re-run the test EXE.
4. Reuse before you write: a `LightCore.* / LightVcl.* / LightFmx.*` unit may already do it.

## Catalog

### Extract Method — long method / duplicated block
Pull a named block into its own method. Target ≤ ~20 lines, one level of abstraction. Name it after *what* it does, not *how*.

### Extract Class — a class doing several jobs
When a class holds two unrelated clusters of fields+methods, split the second cluster into its own class and hold it by composition. This is the usual fix for a god class (see `/light-code-ArchitectureClass`).

### Replace Nested Conditionals with Guard Clauses
Invert edge cases into early `Exit`/`raise` at the top so the happy path runs unindented.

```pascal
procedure Process(AOrder: TOrder);
begin
  if not Assigned(AOrder) then raise EArgumentNil.Create('AOrder');
  if AOrder.Items.Count = 0 then raise EBusinessRule.Create('empty order');
  // happy path, no nesting
end;
```

### Replace Magic Number/String with Named Constant
`const MINIMUM_AGE = 18;` — the name documents intent and kills duplication.

### Replace Conditional with Polymorphism
A `case`/`if` ladder that switches on a type or state and recurs in several places → move each branch into a virtual method on a small class family (Strategy/State). See `/light-ref-DesignPatterns`.

### Introduce Parameter Object
Three-plus parameters that always travel together → gather them into a `record` (value type, no lifetime to manage) and pass that.

### Remove `with`
Replace every `with X do ...` with an explicit `X.` prefix (or a short local alias). `with` hides which scope a name binds to and defeats the IDE.

### Rename for intent
`LCustomerCount` not `N`; `IsActive`/`HasPermission` for booleans; verb+noun for methods. If a name needs a comment to explain it, the name is wrong.

### Inline Method
A one-line pass-through that adds no clarity → fold it back into its callers and delete it.

### Introduce a test seam — WITHOUT an interface
When code is hard to test because it hard-wires a collaborator (a DB layer, a clock, a file), don't reach for an interface by reflex. Gabriel's preference: give the collaborator a **shared base class with virtual methods**, let the SUT hold the base type, and substitute a concrete fake subclass in the test. The IDE can still find every implementer — an interface cannot. Only keep an interface seam where one already exists.

## Final checklist

- [ ] Behaviour identical — same tests green before and after.
- [ ] One logical change per step, each compiled + tested.
- [ ] No new `with`, no new magic literal, no method over ~20 lines.
- [ ] Names reveal intent.
- [ ] New seam uses a shared base, not a new interface (unless one existed).
