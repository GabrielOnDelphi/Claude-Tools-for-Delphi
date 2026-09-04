# New application — template skeleton + Autopilot bridge

Read this **only** when the feature is a whole new application (no existing `.dproj`), before the
feature phases. For a feature added to an existing app, skip the template part and jump to
"Autopilot bridge" (an existing app may still lack the bridge).

---

## 1. Start from a LightSaber template — do not hand-build a skeleton

Copy a LightSaber VCL template and rename it. Two exist:

| Template | Path | Use when |
| -------- | ---- | -------- |
| **Full** *(default for a real new app)* | `c:\Projects\LightSaber\Demo\VCL\Template App Full\` | Any app you intend to ship. Comes with a settings form (`FormSettings`), an `uInitialization.pas` `LateInitialization` that sets up branding, `TGuiSettings`, skins, trial/license (Proteus), splash screen, auto-updater, EULA and file-association — plus a `Lang\` folder of translations and `System\Skins\` `.vsf` styles. |
| **Simple** | `c:\Projects\LightSaber\Demo\VCL\Template App Simple\` | A quick demo / throwaway / minimal tool. Just `FormMain` (`TMainForm = class(TLightForm)`) + a `System\` folder. |

When in doubt for a genuine new application, **start from Full** — it is easier to delete the parts
you do not need than to retrofit updater / settings / translation later.

Steps:

1. Confirm with the user which template (recommend **Full** for a real app, Simple for a quick demo)
   and the new app's name and target folder.
2. Copy the whole chosen template folder to the new location.
3. Rename the project files and the project name:
   - `VCL_TemplateFull.dpr` / `.dproj` / `.dsv`  →  `<NewApp>.dpr` / `.dproj` / `.dsv`
     (or the `VCL_TemplateSimple.*` set for the Simple template).
   - Update the `program <name>;` line in the `.dpr` to match.
   - Set the `AppName` constant in the `.dpr` to the real product name — it names the INI file and is
     *critical* for the `SaveForm`/`LoadForm` (AutoState) feature, so get it right now.
   - Set `AppData.CompanyName` (Simple: in `FormMain.FormPostInitialize`; Full: in
     `uInitialization.LateInitialization`) and, for Full, the `ProductHome` / `ProductSupport` URLs.
4. **Add the Autopilot bridge** (next section) — every app this skill produces must be MCP-drivable.
5. Compile the renamed project via the **`light-compiler` agent** (`AUTOPILOT` Debug config) to
   confirm the copy + bridge build clean before adding any feature code.
6. Then proceed with the feature through the normal phases (Align → … → Implement), treating slice 1
   as the first real feature on top of the working template.

> The template's relative `uses` paths (`..\..\..\FrameVCL\…`, `..\..\..\LightCore.AppData.pas`,
> `..\..\..\Updater\…`) resolve against the LightSaber repo layout. If you copy the app **outside**
> `c:\Projects\LightSaber\Demo\VCL\`, those `..\..\..\` paths no longer point at LightSaber — ask the
> user whether to keep the app inside the LightSaber tree or to fix the search paths / unit references
> for the new location. Do not silently leave broken paths.

---

## 2. Autopilot bridge (every app)

So Claude can *run and test* the program (not just compile it), every app must link the **Autopilot
for Delphi** bridge — a brand-new app (part of step 1 above) **and** an existing app that lacks it,
before implementing the feature. This is what makes the running app drivable via the
`mcp__autopilot__*` tools in Phase 5.

**First check whether the app already has it.** Grep the project for `StartBridge` / `Autopilot.Bridge`.
If present, do nothing. If absent, add it:

1. **Add the bridge unit to the `.dpr` `uses`**, referencing the source in place in your own clone of
   Autopilot for Delphi (https://github.com/GabrielOnDelphi/Autopilot-for-Delphi). VCL apps:

   ```delphi
   uses
     …,
     Autopilot.Bridge.Vcl in '<your Autopilot clone>\Source\Bridge\Autopilot.Bridge.Vcl.pas',
   ```

   FMX apps use the twin `Autopilot.Bridge.Fmx` at the same folder. The INTERFACE always compiles, so
   the `uses` is always valid; the bodies are gated behind the `AUTOPILOT` define (next step).

2. **Call `StartBridge` once, after the main form exists, before `AppData.Run`.** In the LightSaber
   templates the startup is `AppData.CreateMainForm(...)` then `AppData.Run` — put the call between
   them (NOT the README's vanilla `Application.CreateForm` placement, which these templates do not use):

   ```delphi
   AppData:= TAppData.Create(AppName, '', MultiThreaded);
   AppData.CreateMainForm(TMainForm, …, asFull);
   Autopilot.Bridge.Vcl.StartBridge;   // <-- bridge: safe no-op unless AUTOPILOT is defined
   AppData.Run;
   ```

3. **Add `AUTOPILOT` to the Debug build's conditional defines** (Project Options → Building → Delphi
   Compiler → Conditional defines, Debug config). Release builds without the define compile
   `StartBridge` as a no-op — **zero runtime cost in production, no automation in shipped binaries.**
   Set the define on Debug only; do not add it to Release.

4. **Register the MCP server once per machine** (not per app) and link the briefing doc:
   - If `claude mcp list` does not already show `autopilot` as connected, tell the user to run
     `claude mcp add autopilot -- "<path>\Autopilot.Mcp.exe"` — **the user must run this; you cannot
     self-register**, and a newly-registered server only appears in the *next* session.
   - Add one line to the new app's `CLAUDE.md`: *"See `AI-INSTRUCTIONS.md` for how to drive this app
     via the Autopilot for Delphi MCP server."* The canonical briefing is `AI-INSTRUCTIONS.md` at the
     root of your Autopilot clone.

5. **Compile via the `light-compiler` agent** with the `AUTOPILOT` Debug config to confirm the bridge
   links cleanly before any feature code goes in.

> Caveat: the `mcp__autopilot__*` tools must be loaded **this** session to drive the app in Phase 5.
> If you just had the user register the server, the tools appear only next session — note that, and
> either continue without live driving or ask the user to restart the session.
