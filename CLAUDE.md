# CLAUDE.md — internal notes (not for the public)

This folder is the **public showcase repo** `Claude-Tools-for-Delphi`. Its job is **marketing**: promote Gabriel's books (*Delphi in All Its Glory*, 5 titles) and apps (BioniX, LightSaber) by sharing a curated subset of the Claude Code agents/skills he uses for Delphi.

It is **not** the source of truth for the agents/skills. The authoritative copies live in `c:\AI\Claude Code\Skills\` and the live runtime copies in `c:\Users\trei\.claude\`. Only publish here what is clean, generic, and safe to show — strip anything that leaks private paths, product internals, or business info.

## Git

- Remote: `origin` → https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi
- Branch: `main`. Push with `git push`.
- Owner account: `GabrielOnDelphi`. The local `gh` token has `repo` scope (no `delete_repo`).

## Conventions

- README is **promotional** — keep it pointed at the books and apps, not at implementation detail. Verify every claim/URL before publishing (no invented Amazon links).
- `descript.ion` files are Total Commander folder-comment metadata. Harmless; left tracked. Add a `.gitignore` for them if they ever become noise.
- `*.url` files are Windows shortcuts to the book/site landing pages — fine to keep as promo entry points.

## When adding a new agent/skill here

1. Author/maintain it under `c:\AI\Claude Code\Skills\` first.
2. Copy a sanitized version into this folder.
3. Update the README table if it adds a public-facing capability.
4. `git add -A && git commit && git push`.
