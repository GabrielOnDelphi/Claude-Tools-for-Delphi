"""Find every BARE catch in a Delphi project - an `except` with no `on ... do` handler at all -
and sort each one into the pile that says whether it needs a verdict.

    python find-bare-catches.py "c:\\Projects\\LightSaber" --exclude UnitTesting --exclude Demo --exclude External

Why this is a script and not a regular expression: what defines a bare catch is a NEGATIVE - what is
NOT the next token after the `except` - and ripgrep's engine has no lookahead. And why it blanks the
source first: Delphi has four things that look like code and are not ({ } and (* *) comments, both of
which span lines, // to the end of a line, and '...' string literals). A search that reads those as
code reports blocks that have a handler as bare catches, counts commented-out blocks as live, and -
worst - calls a swallowing block correct because the word `raise` appears in its own comment.

Run test-find-bare-catches.py after ANY change to this file. It checks the output against fifteen
blocks whose true answer is written down, and every fault this script has ever had was invisible
without it: two earlier versions reproduced their own totals exactly while getting entries wrong.
"""

import argparse, io, os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')


def blank(text):
    """Replace every comment and every string literal with spaces, keeping the length and every
       newline, so line numbers never move. Delphi has four of them: { } and (* *) span lines,
       // runs to the end of the line, '...' never spans one."""
    out, i, n, state = list(text), 0, len(text), 0   # 0 code  1 {}  2 (**)  3 '..'  4 //
    while i < n:
        c = text[i]
        if state == 0:
            if   c == '{':                              state = 1; out[i] = ' '
            elif c == '(' and text[i+1:i+2] == '*':     state = 2; out[i] = out[i+1] = ' '; i += 1
            elif c == "'":                              state = 3; out[i] = ' '
            elif c == '/' and text[i+1:i+2] == '/':     state = 4; out[i] = out[i+1] = ' '; i += 1
        elif state == 1:
            out[i] = '\n' if c == '\n' else ' '
            if c == '}': state = 0
        elif state == 2:
            out[i] = '\n' if c == '\n' else ' '
            if c == '*' and text[i+1:i+2] == ')':       out[i+1] = ' '; i += 1; state = 0
        else:                                            # 3 and 4 both end at the line end
            out[i] = '\n' if c == '\n' else ' '
            if c == '\n' or (state == 3 and c == "'"):  state = 0
        i += 1
    return ''.join(out)


WORD  = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
OPENS = ('begin', 'case', 'try', 'asm')


def body_of(src, pos):
    """From just after an EXCEPT keyword, return the body up to that block's own END.
       Counts begin/case/try/asm up and end down, so a nested block never ends the search early
       and there is no line cap to truncate a long handler."""
    depth = 0
    for m in WORD.finditer(src, pos):
        w = m.group(0).lower()
        if w in OPENS:
            depth += 1
        elif w == 'end':
            if depth == 0:
                return src[pos:m.start()]
            depth -= 1
    return src[pos:]


PILES = ('RERAISES', 'madExcept', 'CONDITIONAL', 'WRAPPED', 'SWALLOWS', 'NO-MADEXCEPT')

# Piles that are correct by construction and are cleared without reading the block.
CLEARED = ('RERAISES', 'madExcept')


def scan(root, exclude):
    res = {k: [] for k in PILES}
    files = []
    for dirpath, dirs, fns in os.walk(root):
        dirs[:] = [d for d in dirs if d not in exclude]
        files += [os.path.join(dirpath, f) for f in fns if f.lower().endswith('.pas')]

    for f in files:
        raw = io.open(f, encoding='utf-8', errors='replace').read()
        src = blank(raw)                             # comments and strings gone, line numbers intact
        rel = os.path.relpath(f, root)
        uses_madexcept = re.search(r'\bmadExcept\b', src, re.I) is not None
        for m in re.finditer(r'\bexcept\b', src, re.I):
            if re.match(r'\s*\bon\b[\s(]', src[m.end():], re.I):
                continue                             # it has a handler: not a bare catch
            b = ' '.join(body_of(src, m.end()).split())
            line = src.count('\n', 0, m.start()) + 1
            bare_raise = re.search(r'\braise\s*;', b, re.I) is not None
            any_raise  = re.search(r'\braise\b',   b, re.I) is not None
            if   bare_raise and re.search(r'\bif\b', b, re.I): kind = 'CONDITIONAL'
            elif bare_raise:                                   kind = 'RERAISES'
            elif any_raise:                                    kind = 'WRAPPED'
            elif re.search(r'\bhandleexception\b', b, re.I):   kind = 'madExcept' if uses_madexcept else 'NO-MADEXCEPT'
            else:                                              kind = 'SWALLOWS'
            res[kind].append((rel, line, b))
    return len(files), res


def main():
    ap = argparse.ArgumentParser(description='Find bare try..except blocks in Delphi source.')
    ap.add_argument("project", help="folder to scan, as a full absolute path")
    ap.add_argument("--exclude", action="append", default=[],
                    help="folder NAME to skip; repeat the flag once per folder")
    ap.add_argument("--report", default=None, help="write the output to this file as well")
    ap.add_argument("--all", action="store_true",
                    help="also list the cleared piles (RERAISES, madExcept), not only the ones needing a verdict")
    a = ap.parse_args()

    n_files, res = scan(a.project, a.exclude)

    buf = io.StringIO()
    w = buf.write
    w('Bare try..except report\n')
    w('Project : %s\n' % a.project)
    w('Skipped : %s\n' % (', '.join(a.exclude) if a.exclude else '(nothing)'))
    w('Files   : %d .pas\n\n' % n_files)
    for k in PILES:
        w('### %-12s : %d%s\n' % (k, len(res[k]), '   (cleared without reading)' if k in CLEARED else ''))
    w('TOTAL bare catches: %d\n\n' % sum(len(v) for v in res.values()))

    listed = PILES if a.all else [k for k in PILES if k not in CLEARED]
    for k in listed:
        if not res[k]:
            continue
        w('--- %s ---\n' % k)
        for f, l, b in sorted(res[k]):
            w('%-52s:%-5d %s\n' % (f, l, b[:95]))
        w('\n')

    out = buf.getvalue()
    print(out, end='')
    if a.report:
        io.open(a.report, 'w', encoding='utf-8').write(out)
        print('Written to %s' % a.report)


if __name__ == '__main__':
    main()
