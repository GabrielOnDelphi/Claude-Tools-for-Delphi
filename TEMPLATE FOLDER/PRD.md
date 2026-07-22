# PRD — <feature name>

## Problem
<one paragraph: what user pain does this solve?>

## Solution sketch
<one paragraph: the shape of the answer>

## User stories
- As a <role>, I want <action>, so that <outcome>.

## Affected units
- <Unit.pas> — <what changes>
- <Form.pas> + <Form.fmx/.dfm> — <what changes>

## DFM/FMX changes
<new controls? layout reflow? component renames?>

## Binary serialization impact
<does this change any TLightStream Save/Load?
 if yes: version bump strategy + backward-compatibility path>

## Threading model
<main thread / TThread / TTask / mix>

## AppData / INI settings
<new keys? renamed keys? defaults? affected AutoState?>

## DUnitX test plan
<which units get a *Test.pas? what is asserted at each level?>

## Build target
<Debug / PreRelease / Release — and the reason if not Debug>

## LightSaber dependencies
<which LightSaber units used? any new ones added?>

## Cross-platform
<Windows-only / also Android / also iOS — note platform-specific paths>

## Out of scope
<what we are explicitly NOT doing — important for the definition of done>
