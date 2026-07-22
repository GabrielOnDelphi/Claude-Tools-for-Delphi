---
name: light-code-Win64Audit
description: Audit Delphi source for Win64 truncation bugs — pointer-width API results (DWORD_PTR/LRESULT/handles) stored in 32-bit variables (Integer/Cardinal/DWORD/UInt), and 32-bit casts of pointers passed to the API. Say "audit for Win64 bugs", "check 64-bit safety", "search for SysIL-class bugs".
---

# /light-code-Win64Audit — Win64 pointer-truncation audit

Finds the bug class that broke a real shipping app on Win64: `SysIL: UInt := SHGetFileInfo(...)` — a pointer-width API result stored in a 32-bit variable. Compiles silently; explodes only on Win64 (ERangeError with range checking, or a corrupted handle without it).

This is a thin launcher: resolve the scope, launch the audit agent(s), summarize. Discovery is done by GREP (deterministic, free), never by reading every file with an LLM. The agent reads code only at grep hits, to check the receiver's declared type.

## Step 1 — Resolve scope

`$args` = one or more folders (or .pas files). No argument → ask which folder to audit; never default to all of c:\Projects without being told.

Default EXCLUDES (skip hits whose path contains): `backup`, `Backups`, `before upgrade`, `ToDo`, `Testers`, `Tester `, `RESURSE`, `FACUT DE ALTII`, `old`. These are archives — report a one-line count for them, nothing more. Do NOT exclude `External`/third-party folders that are LINKED into shipping projects (LightSaber\External\DiskDrives.pas was the original bug).

## Step 2 — Launch the audit agent

Call the **Agent** tool, `subagent_type: "general-purpose"`, `model: "sonnet"` (user says "cheap"/"haiku" → `model: "haiku"`). If the scope has more than ~800 .pas files, split by top-level subfolder into up to 4 agents launched in parallel, one folder set each.

Give each agent this brief verbatim, plus its folder list:

---

You audit Delphi code for Win64 pointer-truncation bugs. REPORT ONLY — never edit files.

**A. Run this grep battery** (ripgrep via the Grep tool, glob `*.{pas,dpr,inc}`) over the given folders:

1. `:=\s*(SHGetFileInfo|ShellExecute\w*|SetTimer|SetWindowsHookEx|GetProp|FindFirstUrlCacheEntry|GetWindowLongPtr|SendMessage\w*|FileOpen|LoadLibrary|GetModuleHandle|FindWindow\w*|GlobalAlloc|GetStockObject|GetClipboardData|ImageList_\w+|CreateCompatible\w+)\(` — API results; check each RECEIVER's declared type.
2. `(Set|Get)(Window|Class)Long(Ptr)?\([^;\r\n]*\b(Integer|Longint|LongInt|Cardinal|LongWord)\(` — 32-bit casts around window-data calls.
3. `(Send|Post)Message\w*\([^;\r\n]*\b(Integer|Longint|LongInt|Cardinal)\(` — 32-bit casts in wParam/lParam.
4. `\b(Integer|Longint|LongInt|Cardinal|LongWord|DWORD)\(\s*@` — procedure address truncated to 32 bit.
5. `OldWndProc\s*:\s*(Integer|Longint|LongInt|Cardinal|DWORD|LongWord)` (case-insensitive) — stored window proc in 32-bit variable.
6. `\b(h[A-Z]\w*|\w+Handle|\w+Wnd)\s*:\s*(Integer|Cardinal|LongWord|UInt|DWORD)\b` — handle-named variables declared 32-bit.
7. `\.Result\s*:=\s*(Integer|Longint|LongInt)\(` — pointer stuffed into a message Result via a 32-bit cast.

**B. Verify every hit before flagging.** Read the declaration of the receiver variable (and the surrounding routine). Verify the API's return type in the Delphi source at `c:\Delphi\Delphi 13\source\` — never assert a signature from memory. Pre-verified facts (Delphi 13, checked 2026-07-22) you may reuse without re-reading:

- `SHGetFileInfo` → `DWORD_PTR` (Winapi.ShellAPI.pas:923). With SHGFI_SYSICONINDEX the value is the system image-list HANDLE.
- `ShellExecute` → `HINST` (Winapi.ShellAPI.pas:59); `HINST = THandle` (System.pas:2212) — pointer-width.
- `SendMessage` → `LRESULT = INT_PTR` (Winapi.Windows.pas:27185, 3839). Truncation matters only when the message returns a pointer/handle (EM_GETHANDLE, CB/LB_GETITEMDATA...); a line index into Integer is benign.
- `SetTimer` → `UIntPtr` (Winapi.Windows.pas:29007).
- `GetProp` → `THandle` (Winapi.Windows.pas:30029).
- `FindFirstUrlCacheEntry` → `THandle` (Winapi.WinInet.pas:3069).
- `FileOpen` → `THandle` (System.SysUtils.pas:1435).
- `HWND = UINT_PTR` (Winapi.Windows.pas:3881); `HMODULE`/`HINST` = THandle (4091-4092).
- `GetWindowLong`/`SetWindowLong` in Delphi 13 are `NativeInt` INLINE FORWARDERS to the *Ptr variants (Winapi.Windows.pas:30475-30485, 42547, 42919). A bare call is value-safe; the bug is only a 32-bit cast around it or a 32-bit receiver. Older Delphi versions differ — if the project targets < Delphi 12, re-verify in that version's source.
- FALSE-POSITIVE guards: `GetFileVersionInfoSize` handle out-param is genuinely `DWORD` (Winapi.Windows.pas:37202). Process/thread IDs are DWORD. `WaitForSingleObject` returns DWORD. `GlobalLock` returns Pointer — a Pointer receiver is correct.

**C. Classify each verified hit:**
- `CONFIRMED` — 32-bit receiver/cast of a pointer-width value, in code that a current project links.
- `LATENT` — wrong width but the value is practically small (e.g. ShellExecute's status result) or the project is Win32-only today. Still worth a one-line fix.
- `FALSE-POSITIVE` — correct per the RTL signature (say why, one line).
- `ARCHIVE` — hit in an excluded-class folder; count only.

**D. Return a report**: per finding — `file:line`, receiver declaration, API + verified return type (with RTL file:line), class, and the one-line fix (the fix is always: declare the receiver with the API's own type — `DWORD_PTR`/`HINST`/`THandle`/`NativeInt` — or replace the cast with `WPARAM`/`LPARAM`/`NativeInt`). End with totals per class.

---

## Step 3 — Summarize and (only if asked) fix

Relay the agent report. Apply fixes ONLY if the user asked for fixes: one-line type change + short why-comment at each CONFIRMED/LATENT site, then compile the owning project via the **light-compiler** agent (never MSBuild by hand), both platforms when the project has Win64.

## Notes

- The in-house DUT tool (`Tool - Light Delphi utilities (DUT)\dutWin64Api.pas`) already scans patterns 2-3 (casts in SendMessage/Perform/SetWindowLong). This skill's main added value is pattern 1/6 — the RECEIVER-width class DUT does not cover.
- Origin: `LightSaber\External\DiskDrives.pas` SysIL bug, root-caused 2026-07-21 (see `Autopilot for Delphi\Issues\vcl-win64-bridge-not-starting.md`). LightSaber itself was fully audited + fixed 2026-07-22 — re-run there only after importing new code.
