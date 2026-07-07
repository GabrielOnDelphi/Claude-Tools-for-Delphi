---
name: light-ref-Memory
description: Reference for Delphi memory-safety and exception handling — the try..finally gold standard, freeing owned fields, FreeAndNil, Owner-managed components, functions that return objects, specific try..except, domain exception hierarchies and bare raise. Load this when writing or reviewing code that creates objects, manages lifetimes, or handles exceptions.
---

# Delphi memory & exceptions — reference

Class instances are freed manually, on every target — desktop and mobile alike, no GC. Every ownerless `Create` must be freed on every path, the exception path included. The checklist at the end is the single source of truth: the `light-review-step1` and `light-review-step3` agents read this file and apply it, so keep the list here and nowhere else.

## try immediately after Create

Anything between `Create` and `try` can raise and leak the instance.

```pascal
LList := TStringList.Create;
try
  LList.Add('item');
finally
  LList.Free;
end;
```

Several locals: nest `try..finally` in reverse creation order, or `nil` them all up front and `FreeAndNil` each in one `finally`.

## Functions that return an object — guard the newborn

If a later step raises before the caller receives the result, it leaks:

```pascal
function BuildList: TStringList;
begin
  Result := TStringList.Create;
  try
    Fill(Result);        // may raise
  except
    Result.Free;         // free before propagating
    raise;
  end;
end;
```

Never pass an inline `.Create` as a parameter unless the callee definitely takes ownership.

## FreeAndNil vs Free · Owner-managed

- `FreeAndNil(F)` for a **field** that may be re-tested with `Assigned` or freed twice; plain `Free` for a local that dies at end of scope.
- A component created **with an Owner** — `TButton.Create(Self)` — is freed by that Owner. Do **not** free it yourself.
- Owned fields allocated in a constructor are freed in the **destructor**, `inherited` last.

## Exceptions: specific, never swallowed

Catch the narrowest type you can act on. A bare `except ... end` hides `EAccessViolation`, `EOutOfMemory` and real bugs.

```pascal
try
  Commit;
except
  on E: EFDDBEngineException do
  begin
    Log(E.Message);
    raise EDatabaseError.Create('Service temporarily unavailable');  // translate to a domain error
  end;
end;
```

- Re-raise with a bare `raise;` — `raise E;` resets the stack trace.
- Prefer a small domain tree (`EBusinessRule` / `EInfrastructure` and their subclasses) over scattered `raise Exception.Create('...')`, so upper layers can catch by category.

## Review checklist

- [ ] Every ownerless `Create` has `try..finally` (or `try..except..Free..raise` for a returned object).
- [ ] `try` sits immediately after `Create`.
- [ ] Destructors free owned fields and call `inherited` last; Owner-managed instances are NOT freed by hand.
- [ ] No object leaked on the exception path.
- [ ] `except` catches specific types; nothing swallowed silently.
- [ ] Re-raise uses bare `raise;`.
