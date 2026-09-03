---
name: light-ref-DesignPatterns
description: Quick index of the GoF design patterns that actually pay off in Delphi desktop/mobile code, each with its Delphi-native shortcut (anonymous methods, virtual methods, System.Messaging, class functions, enumerators) so you reach for the full pattern only when it earns its keep. Load this when choosing a structure for varying behaviour, decoupling producer from consumer, building objects step by step, or wrapping/adapting a subsystem. Adapted to Gabriel's stack: composition and concrete types first, interfaces only where they genuinely pay, no over-engineering.
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# Design patterns in Delphi — reference

Gabriel writes on this, so this is a decision index, not a tutorial. Two rules before applying any pattern:

- **YAGNI** — do not add a pattern for a variation point that does not exist yet. A `case` statement with two branches does not need Strategy.
- **Delphi already ships the pattern.** Anonymous methods (`TProc`/`TFunc`), virtual methods, generics, `System.Messaging`, enumerators and `TObjectList<T>` collapse most textbook GoF into a few lines. Use the built-in before the class hierarchy, and prefer a shared base class to an interface unless the seam is a real plug-in point.

## Index

| Pattern | Use when | Delphi-native shortcut |
|---|---|---|
| **Strategy** | one step of an algorithm varies | pass a `TFunc<..>`/`TProc<..>`; only make a class family if the strategy holds state |
| **Template Method** | fixed skeleton, a few varying steps | `virtual`/`abstract` methods on a base class, overridden by descendants |
| **State** | behaviour changes with an object's mode, `case` ladders repeat | a small state class per mode behind a base class; swap the field |
| **Observer** | many parts must react to a change, loosely coupled | `System.Messaging.TMessageManager` (subscribe/broadcast) — no hand-rolled listener list |
| **Command** | wrap an action as a value (undo, queue, macro) | often just a `TProc`; a class only when you need undo/serialisation |
| **Factory Method** | pick a concrete type at runtime | a `class function Create...: TBase` that returns the right descendant |
| **Abstract Factory** | create a whole family of related objects | one factory class with several `class function`s |
| **Builder** | object needs many optional steps to construct | fluent methods returning `Self`, then `Build` |
| **Adapter** | fit a foreign/legacy API to yours | a thin wrapper class exposing your shape, delegating inward |
| **Decorator** | add behaviour without subclass explosion | a wrapper holding the wrapped object and forwarding, adding around it |
| **Facade** | hide a messy subsystem behind one door | one coarse class with a few methods over the tangle |
| **Proxy** | control access (lazy load, cache, guard) | a stand-in class with the same surface as the target |
| **Chain of Responsibility** | try handlers in order until one copes | a list of handler objects, or an ordered list of `TFunc<..,Boolean>` |
| **Singleton** | exactly one shared instance | a unit-level accessor `function Foo: TFoo` freed in `finalization` — beware shared mutable state and threads |

## Two sketches worth spelling out

Strategy as an anonymous method — no class needed:

```pascal
procedure Sort(AList: TList<TItem>; const ALess: TFunc<TItem, TItem, Boolean>);
```

Template Method — skeleton in the base, hooks overridden:

```pascal
type
  TImporter = class
  public
    procedure Run;                 // the fixed skeleton
  protected
    procedure ReadSource; virtual; abstract;
    procedure Validate; virtual;   // sensible default, optional override
    procedure Persist; virtual; abstract;
  end;

procedure TImporter.Run;
begin
  ReadSource;
  Validate;
  Persist;
end;
```

## Choosing / reviewing

- Prefer the built-in shortcut; escalate to a class family only when state or count justifies it.
- New variation seam → shared base class first; interface only for a genuine external plug-in point.
- Singleton and any shared cache: guard mutable state across threads (see `/light-ref-Threading`).
- If a pattern adds indirection without a second concrete case in sight, remove it (YAGNI).

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
