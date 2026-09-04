# Universal Bug-Fix Workflow

Reusable checklist. Apply to any bug report.

**Source of the report:**
- `.eml` or `.txt` files inside the bug folder (screenshots, emails, logs). **Check these first.**
- If no email in the folder, the user may point to a Thunderbird folder path — read the `.eml` there.
- Images: `.png`/`.jpg` may be permission-blocked — if so, note the limitation and ask the user to describe the image OR to copy it to an accessible path.

---

## Steps

### 1. One-line summary
Read everything in the bug folder. Write ONE line summarizing the issue(s). Show it to the user for confirmation of scope.

### 2. Questions — only if blocked
Only ask if you cannot proceed. Do not ask for things you can check yourself (code, version strings, INI keys, release notes, logs). Batch all questions into one message.

### 3. Fix bug
- Trace full call chain before editing (root cause, not symptom).
- Check related unit tests first — extend or add tests if behavior can be covered.
- Keep edits minimal. No opportunistic refactors.
- Follow Delphi conventions in `CLAUDE.md` (FreeAndNil, EXIT(value), no `with`, bump file header date, etc.).

### 4. Review fixes
- Re-read the diff in full.
- Launch `delphi-review` agent on touched units for a deep pass.
- Confirm no compiler hints/warnings introduced.

### 5. Update version + compile
- Bump version in `BionixWallpaper.dproj` (and any `About` constant / resource version).
- Use `delphi-compiler` agent to build. Do NOT kill running BioniX.
- Beep when done.

### 6. Update website
- Bug fix or feature → edit the features page in your website's local source folder, e.g. `c:\Projects-www\<yoursite.com>\features\index.html`.
- Add to changelog / bug-fix section. Assets under `features\images\`.
- Same session as the code change.

### 7. Reply email to user
- Short. Non-technical. No jargon.
- Confirm what was fixed. Invite retest. Thank for the report.
- Write to `Reply - <short topic>.txt` inside the bug folder.

---

## Output checklist (end of run)
- [ ] Summary line shown
- [ ] Code fixed + reviewed
- [ ] Version bumped
- [ ] Build OK
- [ ] Website updated
- [ ] Reply email drafted
