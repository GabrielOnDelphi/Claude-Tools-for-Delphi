# Delphi madExcept crash reporting (integration notes)

madExcept / madShi is the crash- and exception-reporting suite for Delphi (madshi.net). Keep your own integration notes next to your madExcept install — a `Claude.md` inside the folder madExcept was installed into, so any Claude session working on that machine can find them.

Mine cover:

- the `madshi` feature-symbol convention for gating madExcept inclusion (set in the `.dproj` `DCC_Define`, not in the `.dpr`);
- runtime detection of whether madExcept is linked in;
- build-config detection via `($IFOPT R+)`;
- the Delphi quirk that `{$...}` directives written for documentation inside `{ }` comments are still parsed by the preprocessor, so use the `($IFDEF X)` parens form inside comments instead.
