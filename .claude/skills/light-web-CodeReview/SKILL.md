---
name: light-web-CodeReview
description: Review HTML, CSS, or JavaScript for errors, formatting, best practices, accessibility, cross-browser issues. Say "review this HTML/CSS/JS", "check my stylesheet", or after writing/editing web frontend code.
---

# /light-web-CodeReview — HTML / CSS / JS Review

This is a thin launcher. Your only job is to resolve the input scope and launch the
**`light-web-CodeReview`** agent. You do NOT review the code yourself.

## Step 1 — Resolve the input

The argument is in `$args`. The user may pass one or more web files, a folder, or nothing.
Build the **review set**:

- **One or more explicit file paths** (`.html`, `.htm`, `.css`, `.js`, `.mjs`) → use them as-is.
- **A folder** → Glob `<folder>/**/*.{html,htm,css,js,mjs}` for the file list. If the result is
  large (more than ~25 files), tell the user the count and ask whether to review all or narrow
  the scope.
- **No argument** → review the web files with **uncommitted** changes. Run
  `git status --porcelain` and keep the `.html` / `.css` / `.js` files it lists. The agent
  reviews recently changed code by default, so this matches its intent. If that list is empty,
  ask the user which file or folder to review.

Print the resolved review set as a short list before launching.

## Step 2 — Launch the agent

Call the **Agent** tool with `subagent_type: "light-web-CodeReview"`. Pass it the **full
review set** in one prompt — HTML, CSS, and JS together when present, so it can cross-reference
(e.g. unused CSS selectors against the HTML, missing handlers against the markup).

**Relay its final report** to the user.

## Step 3 — Summary

Print a short summary (the agent's full report is already in the transcript — do not re-paste
it): how many files reviewed and how many issues by severity / category.

## Rules

- **You do not review code.** Resolving the scope, launching the agent, and summarizing is your
  entire job. The agent does the review.
- **Recently changed code by default.** Do not expand to the whole codebase unless the user
  explicitly asks.
