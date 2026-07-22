## Post Review 2

  Take the review findings already in this conversation and run them through a counter-analysis pass before fixing
  anything.

  Step 1 — Counter-analysis
  For each finding, look for oversights, exaggerations, or wrong assumptions in the original analysis. Some of your
  suppositions WILL be false — this happens every review. Treat the prior findings as a hypothesis, not a verdict.

  Step 2 — Verify
  Confirm every surviving claim is real. For each one:
    - Read the actual file and the surrounding code (not just the snippet quoted in the finding).
    - Read the declaration of every named type, procedure, or property referenced.
    - For RTL/FMX/VCL APIs, check c:\Delphi\Delphi 13\source\ or the Embarcadero DocWiki.
    - For 3rd-party code, check the library source or its docs.
    - If a sub-agent produced any of the findings, always re-check its conclusions — don't trust them blindly.
  Drop anything you can't verify. Say so explicitly when you drop something and why.

  Step 3 — Revise
  Produce a clean, deduplicated list of the findings that survived verification, with severity and the verified evidence
   (file:line + quoted code) for each.

  Step 4 — Fix everything that survived
  Fix ALL the surviving issues, not just the easy ones. No cherry-picking. If a fix is risky or requires a design
  decision, flag it and ask (but at the very end, for the case when I am AFK) — but don't silently skip it.

  When done, beep:
  powershell -c "(New-Object Media.SoundPlayer 'c:\AI\Claude Code\claude bip.wav').PlaySync()"

## Post Review 1

Follow your previous analysis with a counter-analysis highlighting potential oversights or exaggerations.
Using insights from both analyses, revise and generate an improved version.

I am sure some of your suppositions are false. It happens during each review. 

Confirm if your suppositions are real by reading related files/documentation or by Internet searches. Always check the conclusions of your sub-agents!

Once you eliminated all false positives, start fixing the issues or implementing the items on the list. Don't fix only small issues! Fix all.

## Post fix

Review your recent code changes and REASONING for those changes.
Provide a critical analysis followed by a counter-analysis highlighting potential oversights or exaggerations. 
Using insights from both analyses, revise and generate an improved version.
Confirm if your suppositions are real by reading related files/documentation or by Internet searches.

Then, check if the code in this file integrates with the rest of the code without problems.

------------

## General

Follow with a counter-analysis highlighting potential oversights.

Using insights from both analyses, revise and generate an improved version.
Use multiple agents when useful (for reading related files or Internet searches).