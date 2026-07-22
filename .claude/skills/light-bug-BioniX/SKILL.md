---
name: light-bug-BioniX
description: "Alias for /light-bug-MadShi with the BioniX product preselected. Diagnose and fix a BioniX Wallpaper crash report from Thunderbird, then build (never release). Use when the user says \"/light-bug-BioniX\", \"new BioniX bug report\", \"check the latest BioniX crash\", or similar."
disable-model-invocation: true
---

# /light-bug-BioniX — alias for /light-bug-MadShi bionix

This skill is a thin alias. The real pipeline is the `light-bug-MadShi` skill (the crash-report-specific pipeline; the general `/light-bug` skill routes there too, but this alias skips straight to it).

Do this:

1. Read `c:\Users\trei\.claude\skills\light-bug-MadShi\SKILL.md` and follow it exactly, with the product fixed to **BioniX** (the `[BioniX]` block in `products.ini`). Skip its "resolve the product" question — the product is already known.
2. If `$args` contains a path to an existing `.mad` file, pass it straight through to step 4 of that skill (hand off to the `light-bug-MadShi` agent with the BioniX profile). Otherwise run the list -> pick -> extract -> hand off -> relay flow for BioniX.

Everything else (mbox handling, candidate listing, the agent hand-off, the "do not release" rule) is defined in the general skill. Don't duplicate it here.
