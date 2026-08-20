---
name: light-ref-Threading
description: Reference for writing or reviewing Delphi threading code on VCL and FMX (incl. Android/iOS) — TThread, TThread.CreateAnonymousThread, PPL (TTask/TParallel/TFuture), Synchronize vs Queue, TInterlocked/TCriticalSection/TMonitor/TLightweightMREW, TThreadList/TThreadedQueue/TEvent, graceful cancellation and thread-safety. Load this when a task works with threads, or touches shared state from more than one thread — or when reviewing such code. FMX/mobile-aware. Composition over interfaces.
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# Delphi threading — reference

Load before writing or reviewing any code that runs off the main thread. Threading is RTL/PPL territory — LightSaber has no multithreading helpers, so do not go looking for one.

Units: `TThread` — System.Classes · `TTask`/`TParallel`/`IFuture<T>` — System.Threading · `TCriticalSection`/`TEvent`/`TInterlocked`/`TLightweightMREW` — System.SyncObjs · `TThreadList<T>`/`TThreadedQueue<T>` — System.Generics.Collections · `TMonitor` — System (no uses entry needed).

## The one rule that is never optional

**A worker thread must never touch a visual control or the UI directly.** This holds on VCL and on FMX (Android/iOS included). Marshal every UI update back to the main thread with `TThread.Synchronize` (blocking) or `TThread.Queue` (non-blocking).

```pascal
// WRONG - crash or corruption
TThread.CreateAnonymousThread(procedure begin lblStatus.Text := 'Working'; end).Start;

// RIGHT
TThread.CreateAnonymousThread(
  procedure
  begin
    TThread.Queue(nil, procedure begin lblStatus.Text := 'Working'; end);
  end).Start;
```

**Lifetime — VCL & FMX:** a queued/synchronized closure runs *later* on the main thread; if the form or control it touches was freed meanwhile, you get a dangling access. This is not mobile-only — a VCL form closed while a worker still runs hits it too. It just fires far more often on mobile, where the OS backgrounds the app and tears down views on its own. `Assigned` does **not** save you: a freed object is still non-nil, so `Assigned(Form)` returns True and you crash anyway. Fixes, in order:

1. **Stop the worker before its target is freed.** In the form's `OnClose`/destructor just `Free` the thread: `TThread.Destroy` itself calls `Terminate`, waits for `Execute` to finish, then purges the thread's pending queued closures via `RemoveQueuedEvents(Self)` (`System.Classes.pas`, `ShutdownThread`). Calling `WaitFor`/`Free` from the main thread cannot deadlock on a worker sitting in `Synchronize` — main-thread `WaitFor` pumps the synchronize queue while it waits (`TThread.WaitFor`, both Windows and POSIX branches). Requires `FreeOnTerminate = False` (see pitfall below).
2. **Queue against the thread instance, not `nil`, when the target's lifetime is uncertain.** Inside a `TThread` subclass simply call the instance `Queue(...)` — it forwards to `Queue(Self, ...)`. Destroying that thread then purges its pending closures; `TThread.Queue(nil, ...)` has no such safety net. `nil` is fine only when the closure touches nothing that can die before it runs.

## Pick the smallest tool that fits

| Need                                        | Use                                        |
| ------------------------------------------- | ------------------------------------------ |
| One-shot background job                     | `TThread.CreateAnonymousThread(...).Start` |
| Modern pooled task                          | `TTask.Run(...)` (System.Threading)        |
| Async result you read later                 | `TTask.Future<T>(func)` returning `IFuture<T>` |
| Data-parallel loop over independent items   | `TParallel.For`                            |
| Long-lived worker / server / queue consumer | subclass `TThread`, override `Execute`     |

## Synchronize vs Queue

|                       | Blocks worker?              | Use for                              |
| --------------------- | --------------------------- | ------------------------------------ |
| `TThread.Synchronize` | yes — waits for main thread | you need a value back from the UI    |
| `TThread.Queue`       | no — enqueue and continue   | progress, logs, status, most updates |

Prefer `Queue`. Called *from* the main thread, `Queue` runs the closure immediately; `TThread.ForceQueue` always defers it, with an optional delay: `TThread.ForceQueue(nil, proc, 500)` runs it ~500 ms later on the main thread.

## Subclassed worker (correct skeleton)

```pascal
type
  TDataProcessor = class(TThread)
  private
    FDone, FTotal: Integer;
    FOnProgress: TProc<Integer, Integer>;
  protected
    procedure Execute; override;
  public
    constructor Create;
    property OnProgress: TProc<Integer, Integer> write FOnProgress;
  end;

constructor TDataProcessor.Create;
begin
  inherited Create(True);    // True = created SUSPENDED (call Start to run)
  FreeOnTerminate := False;  // the owner keeps the reference and frees it
end;

procedure TDataProcessor.Execute;
var
  ErrMsg: string;
begin
  try
    while not Terminated do          // graceful cancellation checkpoint
    begin
      DoOneChunk;
      if Assigned(FOnProgress) then
        Queue(procedure begin FOnProgress(FDone, FTotal); end);   // instance Queue: purged if the thread is freed first
    end;
  except
    on E: Exception do               // thread exceptions are SILENT otherwise
    begin
      ErrMsg := E.Message;           // copy NOW - see capture rule below
      Queue(procedure begin ReportError(ErrMsg); end);
    end;
  end;
end;

// Owner side - form OnClose/OnDestroy:
FreeAndNil(FProcessor);   // Destroy = Terminate + WaitFor + purge queued closures
```

**Capture rule:** anonymous methods capture **variables, not values** — the closure reads them when it *runs*, not when it is queued. That is why `ErrMsg` is copied first: a closure using `E.Message` directly would dereference `E` after the `except` block already freed the exception object. Same trap with a `for` loop variable: every queued closure sees its final value.

## FreeOnTerminate pitfall

`FreeOnTerminate := True` means the thread frees itself the moment `Execute` returns — any reference you kept goes stale at an unpredictable time. Never keep a reference to such a thread, never call `WaitFor`/`Terminate` on it after `Start`. Anonymous threads are created with `FreeOnTerminate = True` (`TAnonymousThread.Create` in `System.Classes.pas`), so they are fire-and-forget by design. If you need to cancel or wait, use the skeleton above: `FreeOnTerminate := False` and owner-side `Free`.

## Protecting shared state — cheapest that is correct

| Primitive                                             | Use for                                                                              |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `TInterlocked.Increment/Add/Exchange/CompareExchange` | atomic Integer/Int64 counters and flags — no lock                                    |
| `TCriticalSection`                                    | short critical region; `Enter` ... `try/finally Leave` — **Leave always in finally** |
| `TMonitor.Enter(Obj)/Exit(Obj)`                       | lock using an existing object, no extra field                                        |
| `TThreadList<T>`                                      | shared list; `LockList` ... `try/finally UnlockList`                                 |
| `TThreadedQueue<T>`                                   | producer/consumer hand-off (bounded, blocking `PushItem`/`PopItem`)                  |
| `TLightweightMREW`                                    | read-heavy shared data: many readers, one writer                                     |
| `TEvent`                                              | signal a worker to stop/wake (`WaitFor(ms)`)                                         |

`TLightweightMREW` is a record — declare it as a field, no Create/Free needed (auto-initialized), and never copy it. Read locks may be recursive; **write locks are not** (recursive `BeginWrite` deadlocks or fails). Skip the old `TMultiReadExclusiveWriteSynchronizer`: on non-Windows platforms it degrades to a plain critical section, so readers stop sharing (`System.SyncObjs.pas` doc comment).

## Cancellation (no interface needed)

The `Terminated` flag is usually enough: check it in every loop. In helper routines called from `Execute` that have no thread reference at hand, use `TThread.CheckTerminated` — it reads the *current* thread's flag. It raises on threads not created by `TThread` (the main thread included), so it belongs in worker code only. If you need a token shared across several jobs, a tiny concrete class over `TInterlocked` beats an interface for Gabriel's stack:

```pascal
type
  TCancelToken = class
  private
    FFlag: Integer;
  public
    procedure Cancel;
    function Cancelled: Boolean;
  end;

procedure TCancelToken.Cancel;
begin
  TInterlocked.Exchange(FFlag, 1);
end;

function TCancelToken.Cancelled: Boolean;
begin
  Result := TInterlocked.CompareExchange(FFlag, 0, 0) = 1;   // atomic read; TInterlocked.Read exists only for Int64/UInt64
end;
```

## Anti-patterns to flag in review

- UI touched from a worker without `Synchronize`/`Queue`.
- `Sleep`/heavy work on the main thread (freezes the app — move to a task).
- Shared variable read/written without a lock or `TInterlocked` (race).
- Exception left unhandled in a thread (dies silently, no stack).
- Fire-and-forget `TTask.Run` without its own `try/except`: a task exception is stored and re-raised only at `Wait`/`Value`; if nobody ever waits, `TTask.Destroy` frees it silently (RTL comment in `System.Threading.pas`: "any pending exceptions are simply tossed here").
- A queued closure capturing `E` from `on E: Exception`, a loop variable, or anything freed before it runs (capture rule above).
- `FreeOnTerminate := True` plus a kept reference or `WaitFor`.
- Worker in `Synchronize` while the main thread blocks on a lock/`TEvent.WaitFor` — mutual wait, deadlock. (Main-thread `TThread.WaitFor` is the exception: it pumps the synchronize queue.)
- Nested locks acquired in inconsistent order (deadlock).

## Platform note

Since Delphi 10.4 the mobile compilers use the **same manual model as desktop** — there is no object ARC on Android/iOS anymore, so the threading and free-ing rules above are identical on every target.

## Checklist

- [ ] Heavy work off the main thread.
- [ ] Every UI update via `Synchronize`/`Queue`.
- [ ] No queued closure can outlive what it touches: worker freed in the form's `OnClose`/destructor, or queued via the instance `Queue`.
- [ ] Shared state protected (`TInterlocked` / lock).
- [ ] `TCriticalSection.Leave` in `finally`.
- [ ] Loops check `Terminated`.
- [ ] Exceptions caught inside the thread/task and marshalled out.
- [ ] `FreeOnTerminate` consistent with whether you keep a reference or `WaitFor`.
- [ ] Threads named via `TThread.NameThreadForDebugging` when debugging.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*
