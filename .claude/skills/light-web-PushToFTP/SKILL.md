---
name: light-web-PushToFTP
description: Release a Delphi tool's new version to its website FTP. Reads the tool's ReleaseProfile.md and follows it. Use when the user says "push <tool> to FTP", "release a new version", "upload the new build", "promote to stable".
---

# Push a tool release to FTP

## Step 1 — Resolve the tool profile
Identify the tool from the user's request (BioniX, DNA Baser, Blizzard DeScrewer, ...).
Read its profile: `<tool root>\Release procedure\ReleaseProfile.md`.
No profile file → STOP and ask the user; offer to create one from the template below.

## Step 2 — Follow the profile
The profile is the single source of truth for that tool: paths, version bump, build config, packer, FTP target, news/upgrade file, verification. Follow it exactly.

## Step 3 — Global rules (override any profile)
- Compile ONLY via the light-compiler agent. Custom config: `--property=Config=PreRelease` (last `/p:` wins).
- **Never ship a Debug build.** Verify the config from the build log flags: PreRelease = `-$R+ -$Q+`; Release = neither.
- madExcept stays in EVERY shipped build.
- Two-build policy: new version ships as PreRelease (checks ON). When proven stable, rebuild same version as Release and swap the EXE.
- **Ask the user before the actual FTP upload** — show file name, size, and target. Never upload without an explicit yes in the current conversation.
- After upload: verify remote file size equals local. Mismatch → re-upload, re-verify.
- Website Sync Rule: update the product's public site in the same session (see the tool's CLAUDE.md).

## Existing profiles
- Each tool keeps its own profile at `<tool root>\Release procedure\ReleaseProfile.md`.

## Profile template (for new tools)
```markdown
# ReleaseProfile — <Tool>
- Dproj: <path>
- Build config: PreRelease (stable swap: Release)
- Version bump: <how / which file>
- Packer: <cmd or n/a>
- Upload: <ftp host, remote path, atomic rename? channels?>
- News/upgrade file: <path or n/a>
- Verify: <expected exe/sfx size fingerprints, remote check>
- Website to update: <features page path>
```
