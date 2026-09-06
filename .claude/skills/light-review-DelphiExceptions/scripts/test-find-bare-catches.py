"""Self-test for find-bare-catches.py. Run it after ANY change to that file:

    python test-find-bare-catches.py

It writes three small Delphi units to a temporary folder, runs the scanner over them, and compares
the result with the answer written on each `except` line as `//@ <pile>` (or `//@ NONE` for a block
that is not a bare catch at all). Nothing is hand-counted: the test reads the expected line numbers
out of the source, so editing a unit can never desynchronise it from its expectations.

Why this file exists. Two earlier versions of the scanner shipped with faults that were invisible to
reading and invisible to their own output: both reproduced their totals exactly, on two days, in two
sessions, while getting entries wrong inside those totals. The awk version reported 100 swallowing
blocks where there were 61. The first Python version filed two real blind catches under "correct,
clear it" because the comment explaining them contained the word `raise`. Neither would have survived
thirty seconds against the blocks below. A count that reproduces proves nothing about the entries
behind it - only a case whose answer you wrote down first does.

Blocks marked REGRESSION are the exact faults that reached a published article.
"""

import io, os, re, shutil, sys, tempfile
from importlib import import_module

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
scanner = import_module('find-bare-catches')


UNITS = {

'u1_shape.pas': """unit u1_shape;
interface
implementation

procedure P1;                    { the except keyword shares its line with code }
begin
  try Foo; except Result:= FALSE; end;                        //@ SWALLOWS
end;

procedure P2;                    { the body starts on the except line }
begin
  try
    Foo;
  except Result:= FALSE;                                      //@ SWALLOWS
  end;
end;

procedure P3;                    { REGRESSION: a brace comment spanning lines hid the handler }
begin
  try
    Foo;
  except                                                      //@ NONE
    { this comment runs over
      three lines and the handler
      sits underneath it }
    on E: EOSError do Bar;
  end;
end;

procedure P4;                    { REGRESSION: a comment opening on the except line hid the block }
begin
  try
    Foo;
  except { we give up here                                    //@ SWALLOWS
           and here }
    Bar;
  end;
end;

procedure P5;                    { REGRESSION: old-style comments were never stripped }
begin
  try
    Foo;
  except                                                      //@ NONE
    (* an old-style comment, and the handler is below it *)
    on E: EOSError do Bar;
  end;
end;

procedure P6;                    { "on" alone on its line is legal Delphi }
begin
  try
    Foo;
  except                                                      //@ NONE
    on
      E: Exception do Bar;
  end;
end;

{ procedure P7;                  REGRESSION: a block kept inside a comment was counted as live
begin
  try
    Foo;
  except
    Bar;
  end;
end; }

end.
""",

'u2_pile.pas': """unit u2_pile;
interface
implementation

procedure Q1;                    { REGRESSION: the word raise inside a string literal }
begin
  try
    Foo;
  except                                                      //@ SWALLOWS
    Log('could not raise the window');
  end;
end;

procedure Q2;                    { REGRESSION: the false negative that reached the article }
begin
  try
    Foo;
  except                                                      //@ SWALLOWS
    { An unguarded raise here would skip the cleanup below,
      so this block only logs. }
    Log('failed');
  end;
end;

procedure Q3;                    { a new exception thrown, the original discarded }
begin
  try
    Foo;
  except                                                      //@ WRAPPED
    raise EMyError.Create('wrapped');
  end;
end;

procedure Q4;                    { re-raises only when a flag says so }
begin
  try
    Foo;
  except                                                      //@ CONDITIONAL
    FreeAndNil(BMP);
    if NOT SilentErrors then RAISE;
  end;
end;

procedure Q5;                    { the correct shape }
begin
  try
    Foo;
  except                                                      //@ RERAISES
    FreeAndNil(Result);
    RAISE;
  end;
end;

procedure Q6;                    { a routine of our own that happens to be called HandleException }
begin
  try
    Foo;
  except                                                      //@ NO-MADEXCEPT
    Handleexception;
  end;
end;

end.
""",

'u3_extent.pas': """unit u3_extent;
interface
implementation
uses madExcept;

procedure R1;                    { REGRESSION: a 40-line cap truncated the body before its raise }
begin
  try
    Foo;
  except                                                      //@ RERAISES
    Log('01'); Log('02'); Log('03'); Log('04'); Log('05'); Log('06'); Log('07'); Log('08');
    Log('09'); Log('10'); Log('11'); Log('12'); Log('13'); Log('14'); Log('15'); Log('16');
    Log('17'); Log('18'); Log('19'); Log('20'); Log('21'); Log('22'); Log('23'); Log('24');
    Log('25'); Log('26'); Log('27'); Log('28'); Log('29'); Log('30'); Log('31'); Log('32');
    Log('33'); Log('34'); Log('35'); Log('36'); Log('37'); Log('38'); Log('39'); Log('40');
    Log('41'); Log('42'); Log('43'); Log('44');
    raise;
  end;
end;

procedure R2;                    { REGRESSION: begin/end on one line let the body run past its END }
begin
  try
    Foo;
  except                                                      //@ SWALLOWS
    if X then begin Y; end;
  end;
  Z;
  raise Exception.Create('unrelated, and outside the block');
end;

procedure R3;                    { a nested try..except must not end the outer body }
begin
  try
    Foo;
  except                                                      //@ RERAISES
    try Cleanup; except end;                                  //@ SWALLOWS
    raise;
  end;
end;

procedure R4;                    { the real thing, in a unit that really uses madExcept }
begin
  try
    Foo;
  except                                                      //@ madExcept
    madExcept.HandleException;
    Result:= FALSE;
  end;
end;

end.
""",
}

MARKER = re.compile(r'\bexcept\b.*//@\s*(\S+)', re.I)


def expectations():
    """Read the answer off each marked line, so no line number is ever typed by hand."""
    want = {}
    for name, text in UNITS.items():
        for n, line in enumerate(text.splitlines(), 1):
            m = MARKER.search(line)
            if m:
                pile = m.group(1)
                want[(name, n)] = None if pile.upper() == 'NONE' else pile
    return want


def main():
    tmp = tempfile.mkdtemp(prefix='bare-catch-test-')
    try:
        for name, text in UNITS.items():
            io.open(os.path.join(tmp, name), 'w', encoding='utf-8').write(text)

        _, res = scanner.scan(tmp, [])
        got = {}
        for pile, hits in res.items():
            for rel, line, _ in hits:
                got[(rel, line)] = pile

        want = expectations()
        fails = 0
        for key in sorted(want):
            have, expect = got.get(key), want[key]
            ok = (have == expect)
            fails += 0 if ok else 1
            print('%-4s %-14s :%-4d expected %-20s got %s'
                  % ('PASS' if ok else 'FAIL', key[0], key[1],
                     expect or '(not a bare catch)', have or '(not reported)'))

        # anything the scanner reports that carries no marker is an invented block
        for key in sorted(set(got) - set(want)):
            fails += 1
            print('%-4s %-14s :%-4d expected %-20s got %s'
                  % ('FAIL', key[0], key[1], '(no block here)', got[key]))

        total = len(want) + len(set(got) - set(want))
        print('\n%d of %d blocks correct.' % (total - fails, total))
        if fails:
            print('FAILED - do not use the scanner until this is green.')
        else:
            print('All green.')
        return 1 if fails else 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
