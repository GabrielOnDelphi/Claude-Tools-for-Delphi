
## Code formatting
GENERAL RULE: LEAVE EXISTING FORMATTING AS-IS.

`:= ` — no space before, one after: `Version:= 1;`

if-then style:
```pascal
if NOT Assigned(Obj) then Exit;  // short form OK

if Something                // if/then/else always on the same column
then DoSomething
else DoSomethingElse;

if Something then           // when "else" is not present
  begin                     // begin/end always indented           
  end;
```