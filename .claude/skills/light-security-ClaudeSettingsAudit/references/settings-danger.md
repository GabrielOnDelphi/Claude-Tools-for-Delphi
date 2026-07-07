Claude Code settings-safety classification.

Sources (verified 2026-07-02):
- https://code.claude.com/docs/en/settings
- https://code.claude.com/docs/en/hooks

This is the source of truth for the light-security-ClaudeSettingsAudit agent. Update it when Claude Code adds fields or when the machine's known-good baseline changes.

# Files to audit

All of these are Claude Code config that can run code or grant access:
- `~/.claude/settings.json`  (user; applies to EVERY project) = `C:\Users\trei\.claude\settings.json`
- `<project>/.claude/settings.json`  (project; shared via git — a cloned or 3rd-party repo SHIPS this)
- `<project>/.claude/settings.local.json`  (local; gitignored)
- any `.mcp.json`  (MCP server definitions)
- Managed (admin): `C:\Program Files\ClaudeCode\`  (trusted, but report anything unexpected here)

Precedence (highest first): Managed > CLI args > Local > Project > User. Permission rules MERGE across scopes; deny beats allow.

Threat model: a repo you cloned, a shared project, or a tampered file plants config that runs commands or leaks credentials. The workspace-trust gate only withholds `permissions.allow` from untrusted folders — it does NOT reliably stop hooks. So hooks and credential-helpers are the real danger even in an "untrusted" folder.

# DANGEROUS — arbitrary code execution or credential/data exfiltration. Review EVERY hit.

- `hooks` — runs arbitrary shell commands (`type:"command"`), HTTP POSTs (`type:"http"` → data exfil), MCP calls, or spawns agents. Events `SessionStart`, `Setup`, `ConfigChange`, `CwdChanged`, `FileChanged`, `InstructionsLoaded`, `UserPromptSubmit`, `PreToolUse` fire AUTOMATICALLY with no user action. No documented trust gate. HIGHEST-risk field. Read every `command` / `url`. Flag: `rm`/`del`, `curl`/`wget`/`Invoke-WebRequest`, `powershell -enc` or any base64 blob, `certutil -decode`, `bitsadmin`, `nc`/netcat, `python -c`/`node -e` one-liners, pipe-to-shell (`| sh`, `| iex`), writes to Startup folders or `Run`/`RunOnce` registry keys, scheduled-task creation, or any URL/host that is not obviously the user's own.
- `apiKeyHelper` — runs a script whose STDOUT becomes your API key (`X-Api-Key` + `Authorization: Bearer`). Malicious script forwards/steals credentials.
- `awsCredentialExport`, `awsAuthRefresh`, `gcpAuthRefresh`, `otelHeadersHelper`, `policyHelper` — all run scripts; output is used as credentials/headers/managed settings.
- `statusLine` with `type:"command"` — runs a command on every status render.
- `fileSuggestion` with `type:"command"` — runs a command for `@` autocomplete.
- `env` containing `ANTHROPIC_BASE_URL`, `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, any `*_BASE_URL`, `*_API_KEY`, `*_TOKEN`, or `HTTP(S)_PROXY` — redirects API traffic to an attacker proxy or injects/leaks credentials.
- `mcpServers` entries and any `.mcp.json` server — `command` + `args` launch an arbitrary process; `npx -y <pkg>` / `uvx <pkg>` fetch and run arbitrary code; a remote `url` (`type:"http"` / `"sse"`) sends your data offsite. Flag unknown packages, unexpected binaries, or non-local URLs.

# SUSPICIOUS — reduces safety or over-broad. Review.

- `permissions.defaultMode` set to anything other than `ask` — `bypassPermissions` and `acceptEdits` cut prompts hard; `auto` / `clickthrough` also reduce them. Any non-`ask` value → review who set it and why.
- `permissions.allow` over-broad rules: `Bash(*)`, `Bash(:*)`, `Bash(curl*)`, `Bash(powershell*)`, `Bash(rm*)`, bare `WebFetch` / `WebSearch`, `Read(**)`, or Read/Edit of secret paths (`.env`, `.ssh`, `credentials`, private keys).
- `enableAllProjectMcpServers: true` — auto-approves every project `.mcp.json` server.
- `enabledMcpjsonServers` — pre-approves named `.mcp.json` servers. Most dangerous in USER/LOCAL settings (as of v2.1.196 the project-settings copy is ignored in untrusted folders).
- `permissions.additionalDirectories` — grants file access outside the project.
- `disableAllHooks` / `disableSkillShellExecution` flipped OFF where the user expected protection, or `allowManagedHooksOnly` removed — context-dependent.

# SAFE — normal and expected.

- `permissions.allow` narrow rules for known tools: `Bash(git status)`, `Bash(npm run test:*)`, specific Read/Edit globs inside the project.
- `permissions.deny` entries — these ADD safety.
- `model`, `outputStyle`, `statusLine` that is `type:"static"`/non-command, `env` with non-sensitive vars (e.g. `NO_COLOR`).
- `hooks` that only invoke the user's OWN known scripts/tools (see baseline below).

# Known-good baseline for THIS machine (do NOT flag as threats)

- Stop / TaskCompleted hook playing `c:\AI\Claude Code\Tools\task_done_beep.wav` — the user's finish beep (global CLAUDE.md → Notifications).
- Recycle-bin PreToolUse hooks calling `RecycleBin.exe` (`c:\Projects\Projects System\RecycleBin.exe\`) — the user's delete/overwrite safety net (see `Info hooks/Recycle-bin safety net.md`).
- MCP server `superdoc` = `cmd /c npx -y @superdoc-dev/mcp` — the user's DOCX tool.
- MCP servers `dpt-debugger`, `claude-in-chrome`, `autopilot`/`autopilot-android`, and the `claude_ai_*` Gmail/Calendar/Drive connectors — the user's own connected servers.
- Light-* skill/agent hooks that call the beep wav.
- The user's own local hook/statusline scripts: `vampire-hook.ps1`, `vampire-statusline.ps1` (ClaudeTokenVampire, `C:\Projects\Projects AI\Claude TokenVampire`) and `delphipraxis-offline-hook.ps1` (light-md-DelphiPraxisOffline tooling). These run on prompt/status/WebFetch by design — SAFE.

Known 3rd-party but user-installed (surface for review, do NOT treat as an attack): the `claude-hud` plugin (GitHub `jarrodwatts/claude-hud`, `node dist/index.js`) runs on every status render. Legitimate but 3rd-party — worth a periodic glance, not an alarm.

Anything matching the baseline is SAFE. Anything that runs a command, sets a credential/proxy env var, or launches an MCP server that is NOT in this baseline goes in DANGEROUS or SUSPICIOUS with the exact line quoted.
