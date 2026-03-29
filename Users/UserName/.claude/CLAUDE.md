# Global Programming Conventions

These conventions apply to all my Delphi projects.
Main target is Delphi 13.1. When possible keep compatibility with lower versions of Delphi, but not lower than Delphi Rio.

## Code review
When performing code reviews:
* Complete the FULL analysis before making any edits
* When trivial issues found - just fix them without asking.
* Place generated files in the project's existing directory structure, not in arbitrary locations.
* Complete the task the user asked for before expanding scope to related improvements.

## Bug fixing
* When the first fix doesn't resolve the issue, step back and re-examine the root cause rather than patching the same area
* Trace the full call chain before applying a fix - look for upstream overwrites

## Speed optimizations
* Never apply performance optimizations without benchmarking first; be prepared to fully revert if performance degrades. 
Don't just suppose the new (optimized) code is better. Write a small test program and benchmark. 

## Critical thinking
ALWAYS do reviews, provide a critical analysis of your initial findings followed by a counter-analysis highlighting any potential oversights.
Using insights from both analyses, revise your proposals and generate an improved version.
Check the Internet for information/news/ideas/documentation.

## Backward compatibility for binary files
Preserve backward compatibility when refactoring serialization/loading code.

## Boilerplate Code

1. Avoid delegation properties if the underlying object is accessible:

```pascal
// Avoid this if User is not a private field:
function TLesson.getColor: TColor;
begin
  Result := User.Color;
end;
procedure TLesson.setColor(const Value: TColor);
begin
  User.Color := Value;
end;
```

Instead use directly 'Lesson.User.Color'.

2. Don't use properties unless we need to put real code in getters/setters. In general properties are preferred over fields but they add a lot of boilerplate code.
So avoid:
  property Age: Integer read FAge write FAge;

## Formatting

No space before `:=` assignment operator, but one space after:
```pascal
// Yes:
Version:= 1;

// No:
Version := 1;
```

For if-then statements, `then` on a new line:
```pascal
//Yes
if Not Assigned(Object) then Exit;

// Yes:
if Something
then DoSomething
else DoSomethingElse;

// No:
if Something then
  DoSomething;

// Yes
if Something then
  begin
  end;

// No
if Something
then begin
  end;
```
Super important: AS A GENERAL RULE, LEAVE CODE FORMATTING AS IT IS!

## Comments
Never delete comments marked with /// (triple-slash documentation comments). This is code that is supposed to be only temporary out. It should be put back.
Also, you are overzealous with deleting comments. Think twice before removing them! Better extra info than no info!

## Safer Code

Never use silent nil checks when the object should never be nil:
```pascal
// No - hides bugs:
if SomeObject = NIL then EXIT;

//  Instead use an assertion or exception to "crash" the program:
Assert(SomeObject <> NIL);
// or
if SomeObject = NIL then raise Exception.Create('...');
```

**Always use FreeAndNil instead of .Free:**
```pascal
FreeAndNil(MyObject);
```

## Function Exit Style

Prefer `EXIT(value)` over setting Result then exiting:
```pascal
// Yes:
if NOT FLesson.AvailableShortQuestions
then EXIT(false);

// Avoid:
if NOT FLesson.AvailableShortQuestions then
begin
  Result := false;
  EXIT;
end;
```

## Code Quality Standards

- Zero tolerance for global variables
- Zero tolerance for compiler hints and warnings
- Zero tolerance for swallowed exceptions
- Zero tolerance for memory leaks

## Forbidden Constructs

**Never use these deprecated or dangerous patterns:**
- `absolute` keyword - Use proper variable references instead
- Raw pointers (`^`, `Ptr^`) - Use object references and dynamic arrays
- Old Pascal `file` type (untyped/typed file I/O) - Use TFileStream, TStreamReader/Writer, TFile from System.IOUtils, or TLightStream from LightSaber
- `Application.ProcessMessages` - Use threads or async patterns
- `with` statement - Causes ambiguity, use explicit references
- Generics when simpler alternatives exist - They increase binary size and compilation time dramatically.

**Save Strings To File**
For text, use StringToFile/StringFromFile in "c:\Projects\LightSaber\LightCore.TextFile.pas"

**Instead of pointers, use:**
```pascal
// Use dynamic arrays instead of pointer arrays
var
  Items: TArray<string>;

// Use object references instead of object pointers
var
  MyList: TList;  // Not TList^
```

**Instead of Application.ProcessMessages:**
```pascal
// Use TThread for background work
TThread.CreateAnonymousThread(
  procedure
  begin
    // Background work here
  end
).Start;

// Or use TTask from System.Threading
TTask.Run(
  procedure
  begin
    // Background work
  end
);
```

**When generics are justified:**
```pascal
// Type-safe dictionary when you need key-value pairs
var
  Cache: TDictionary<Integer, TMyData>;
```

**Avoid generics when simpler alternatives exist** 

**Use generics only when:**
- Type safety is critical
- You need multiple strongly-typed collections
- The pattern is truly reusable across many types

Preffer to write your own custom class instead of using generics. 

## Modern Patterns
- Reduce usage of string helpers. These new features are cool BUT they are not debugable.
- Use constants and enumerations.
- Avoid initialization and finalization sections, because these sections are executed in non-deterministic order.

**Use System.IOUtils for file operations:**
But prefer functions such as ListFilesOf, ListDirectoriesOf, CopyFolder, DeleteFolder, GetFileSize in LightCore.IO.pas.

**Use anonymous methods and closures:**
```pascal
// Background processing
TTask.Run(
  procedure
  var
    Result: Integer;
  begin
    Result := PerformCalculation;
    TThread.Synchronize(nil,
      procedure
      begin
        Label1.Caption := Result.ToString;
      end
    );
  end
);
```

## Exception Handling

**Use specific exception types:**
```pascal
try
  // Risky operation
except
  on E: EFileNotFoundException do
    ShowMessage('File not found: ' + E.Message);
  on E: EAccessViolation do
    ShowMessage('Access violation: ' + E.Message);
  on E: Exception do
    ShowMessage('Unexpected error: ' + E.Message);
end;
```

**Don't swallow exceptions silently:**
```pascal
// Good - log or handle appropriately
try
  RiskyOperation;
except
  on E: Exception do
  begin
    AppData.LogError(E);
    raise;  // Re-raise if caller should know
  end;
end;
```

## Unit Testing

**Test framework**:
DUnitX with TestInsight
Put files in "UnitTesting\" folder in project's folder. 
Run tests with `UnitTesting\BuildTests.cmd`.
Don't write tests for forms.

## Build System

**Main IDE target**: Delphi 13.1
Use the delphi-compiler agent. Don't kill the program if it is already running!
If no Build.cmd exists, **create one** in the project folder with the rsvars.bat + MSBuild commands, then execute it.
Note: The MsBuild wants a Dproj file not a DPR or DPK.
Append `2>&1` to capture both stdout and stderr.

Build configurations:
- **Debug**: Optimized for debugging, no madExcept exception handler
- **PreRelease**: Optimized for speed, with madExcept
- **Release**: Optimized for speed, no range/overflow checking, with madExcept

## Own libraries

**LightSaber Framework**
(in c:\Projects\LightSaber\)
My own custom framework.
Key units:
- `LightCore.AppData.pas` - Extends TApplication. Warning: It replaces the Delphi (app initialization) code in the DPR file with its own code.
- `LightCore.StreamBuff.pas` - Custom binary serialization (TLightStream)
- `LightCore.TextFile.pas` - StringToFile/StringFromFile (use instead of TFile)
- `LightCore.IO.pas` - ListDirectoriesOf, CopyFolder, DeleteFolder (use instead of System.IOUtils)
- `LightCore.LogRam.pas` - Logging: Log.Write/Log.WriteError
- `LightFmx.*` - FireMonkey visual components and utilities

**Proteus Framework**
(in c:\Projects\LightProteus\LightProteus.dpk)
My own licensing system.


**LightSaber AI Client**: 
(in c:\Projects\LightSaber AI Client)
- `AiClient.pas`, `AiClientEx.pas` - AI/LLM client infrastructure.


## External Dependencies

**3rd party libraries**:
General 3rd party libraries (some or none might be used in the current project).
- **GR32** - Graphics32 rendering (c:\Projects-3rd_Packages\Graphics32\)
- **FFmpeg** - Video playback (c:\Projects-3rd_Packages\FF_VCL)
- **OpenSSL** - SSL/TLS (DLLs in project root)
- Other: janFX, AniImg, DirectoryWatch, FastJpegDec, GifProperties, HtmlParserEx, MonitorHelper (all in c:\Projects\LightSaber\External\)

**3rd party tools**:
- **madBasic/madExcept** - Exception handling and bug reporting (c:\Delphi\IDE madShi 510\)


## AppData Architecture (3-layer system)

**1. TAppDataCore** (`LightCore.AppData.pas`) - Platform-agnostic base
- Cross-platform path management (AppData folder, Documents, System folders)
- INI file handling for application settings
- Logging system (`TRamLog`) with severity levels (Verb, Hint, Info, Warn, Error)
- Single instance detection via `SingleInstClassName`
- First-run detection via `RunningFirstTime` property
- BetaTester mode detection
- Command-line parameter handling
- Settings: `AutoStartUp`, `StartMinim`, `Minimize2Tray`, `Opacity`, `HintType`

**2. TAppData** (`LightFmx.Common.AppData.pas`) - FMX-specific functionality
- Extends TAppDataCore
- Form creation management via `CreateMainForm`/`CreateForm`
- AutoState queue system for form restoration (`asPosOnly`, `asFull`, `asNone`)
- Visual log window (`TfrmRamLog`) - auto-created on demand
- Platform-specific startup registration (Windows Registry, macOS LaunchAgents, Linux autostart)
- Application control: `Run()`, `Minimize()`, `Restart()`, `SelfDelete()`
- Dialog helpers: `PromptToSaveFile`, `PromptToLoadFile`
- Global instance: `AppData` (freed in FINALIZATION)

**3. TLightForm** (`LightFmx.Common.AppData.Form.pas`) - Self-saving forms
- Base class for all application forms (instead of TForm)
- Auto-saves form position/size/state to INI file on close
- Auto-restores position/size/state on load
- `AutoState` property controls save/restore behavior
- Mobile toolbar support (back/next buttons for Android/iOS)
- `FormPreRelease` - guaranteed single-call cleanup event
- `CloseOnEscape` property
- Event order: `Loaded` → `FormCreate` → `FormPreRelease` → `SaveForm`

### Key Concepts

**AppData Initialization Pattern**:
```delphi
begin
  AppData:= TAppData.Create('AppName', 'UniqueWindowClassName', MultiThreaded);
  AppData.CreateMainForm(TMainForm, MainForm, asPosOnly);
  AppData.CreateForm(TSecondForm, SecondForm, asFull);
  AppData.Run;  // Sets Initializing:= FALSE
end.
```

**Why It Replaces Standard DPR Code**:
- LearnAssist doesn't use `Application.Initialize`, `Application.CreateForm` directly
- AppData manages the entire application lifecycle
- Forms created via `AppData.CreateForm` are queued and realized later
- Provides consistent cross-platform behavior
- Auto-wires form save/restore without manual code

**Important Properties**:
- `AppData.Initializing`: TRUE during startup, set to FALSE in `Run()`. Used to prevent saving corrupted state if app crashes during initialization
- `AppData.RunningHome`: TRUE if .dpr file exists (development mode)
- `AppData.RunningFirstTime`: TRUE if INI file doesn't exist yet
- `AppDataCore.AppName`: Central identifier used for INI filename, AppData folder name, etc.

**Path Helpers**:
- `AppDataFolder()`: User+App specific (e.g., `C:\Users\Name\AppData\Roaming\AppName\`)
- `AppFolder()`: Where EXE resides (on mobile: Documents folder)
- `IniFile()`: `AppDataFolder + AppName + '.ini'`
- Cross-platform: handles Windows/macOS/iOS/Android differences automatically

**Form AutoState System**:
- `asNone`: No auto-save/restore
- `asPosOnly`: Save/restore position only (Left, Top)
- `asFull`: Save/restore position + all GUI controls (checkboxes, etc.)
- `asUndefined`: Error - must be set via CreateForm


## Notifications

Play a beep sound when finishing a task so the user knows to check the result:
```bash
powershell -c "[System.Media.SystemSounds]::Asterisk.Play()"
```
Note: `[console]::beep()` does NOT work — only `SystemSounds` methods produce audible output.

## Context Window Management
- Before I compact: write your current task status and findings to a memory file in `C:/Users/trei/.claude/projects/` so nothing is lost.
- Do not start new large tasks if you sense context is getting heavy (many large file reads, long conversations). Warn me instead.
- After compaction, re-read any critical files you were working on — don't assume you remember them correctly.
