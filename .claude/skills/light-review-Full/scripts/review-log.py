r"""
review-log.py - write the review-log entry that Step 6 of the light-review-Full skill produces.

Two jobs, both of them deterministic file surgery that a model does slowly and gets subtly wrong:

  1. Prepend a dated block to <project>\ReviewHistory.md, newest first, creating the file if absent.
  2. Enforce the size cap by dropping WHOLE blocks from the bottom - never half a block - while
     keeping at least the 5 most recent whatever the size, then refresh the one-line
     "## Last review" pointer in <project>\CLAUDE.md.

Usage:

  python review-log.py add <project folder>
         --date 2026-09-05
         --verdict "Ready with notes"
         --model "Opus 5"
         --scope "3 files - BxAIEngine.pas, BxAIMaskGen.pas, BxAIProviderComfyUI.pas"
         --result "2 issues fixed; compiles clean."
         --unresolved "1 - ViewportResolver may deadlock if the queue is drained mid-await."
         [--cap-bytes 25600] [--keep 5] [--no-claude-md]

  python review-log.py check <project folder>
         Read-only. Prints the block count, the file size, and the current pointer line.

Exit code 0 on success, 1 on a usage or file error. Every path printed is absolute.
"""

import argparse
import os
import re
import sys

DEFAULT_CAP_BYTES = 25 * 1024      # the ~25 KB cap named in SKILL.md Step 6
DEFAULT_KEEP = 5                   # history integrity wins over the cap
HISTORY_NAME = "ReviewHistory.md"
HISTORY_TITLE = "# Review history"
POINTER_HEADING = "## Last review"

BLOCK_RE = re.compile(r"^## \d{4}-\d{2}-\d{2}\b", re.M)


def read_text(path):
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as f:
        return f.read()


def write_text(path, text):
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def split_blocks(history_text):
    """Return (header, [block, ...]). A block starts at a '## YYYY-MM-DD' line and runs to the
    line before the next one. The header is everything above the first block, title included."""
    if not history_text:
        return HISTORY_TITLE + "\n", []
    starts = [m.start() for m in BLOCK_RE.finditer(history_text)]
    if not starts:
        return history_text.rstrip("\n") + "\n", []
    header = history_text[:starts[0]].rstrip("\n") + "\n"
    bounds = starts + [len(history_text)]
    blocks = [history_text[bounds[i]:bounds[i + 1]].rstrip("\n") + "\n"
              for i in range(len(starts))]
    return header, blocks


def join_blocks(header, blocks):
    if not blocks:
        return header.rstrip("\n") + "\n"
    return header.rstrip("\n") + "\n\n" + "\n".join(blocks).rstrip("\n") + "\n"


def trim_to_cap(header, blocks, cap_bytes, keep):
    """Drop whole blocks from the END (the oldest) until the file fits, never going below `keep`.
    Returns (blocks, dropped_count)."""
    dropped = 0
    while len(blocks) > keep:
        if len(join_blocks(header, blocks).encode("utf-8")) <= cap_bytes:
            break
        blocks = blocks[:-1]
        dropped += 1
    return blocks, dropped


def make_block(date, verdict, model, scope, result, unresolved):
    lines = ["## %s - %s" % (date, verdict),
             "- **Model:** %s" % model,
             "- **Scope:** %s" % scope,
             "- **Result:** %s" % result,
             "- **Unresolved:** %s" % (unresolved if unresolved else "none")]
    return "\n".join(lines) + "\n"


def update_claude_md(project, date, verdict):
    """Overwrite the one-line pointer under '## Last review'. Returns a status string."""
    path = os.path.join(project, "CLAUDE.md")
    text = read_text(path)
    if text is None:
        return "no CLAUDE.md - pointer line skipped"
    line = "%s - **%s** - full history in [%s](%s)" % (date, verdict, HISTORY_NAME, HISTORY_NAME)
    pat = re.compile(r"^## Last review[ \t]*\r?\n(?:(?!^## ).*\r?\n?)*", re.M)
    if pat.search(text):
        text = pat.sub(POINTER_HEADING + "\n" + line + "\n\n", text, count=1)
        status = "pointer line overwritten"
    else:
        text = text.rstrip("\n") + "\n\n" + POINTER_HEADING + "\n" + line + "\n"
        status = "pointer section added"
    write_text(path, text)
    return status


def cmd_add(args):
    project = os.path.abspath(args.project)
    if not os.path.isdir(project):
        sys.stderr.write("not a folder: %s\n" % project)
        return 1
    history_path = os.path.join(project, HISTORY_NAME)
    header, blocks = split_blocks(read_text(history_path))
    blocks.insert(0, make_block(args.date, args.verdict, args.model,
                                args.scope, args.result, args.unresolved))
    blocks, dropped = trim_to_cap(header, blocks, args.cap_bytes, args.keep)
    write_text(history_path, join_blocks(header, blocks))
    size = os.path.getsize(history_path)
    print("wrote   %s" % history_path)
    print("blocks  %d  (%d dropped as oldest to stay under the cap)" % (len(blocks), dropped))
    print("size    %d bytes  (cap %d, floor %d blocks)" % (size, args.cap_bytes, args.keep))
    if not args.no_claude_md:
        print("CLAUDE  %s" % update_claude_md(project, args.date, args.verdict))
    return 0


def cmd_check(args):
    project = os.path.abspath(args.project)
    history_path = os.path.join(project, HISTORY_NAME)
    text = read_text(history_path)
    if text is None:
        print("no %s in %s" % (HISTORY_NAME, project))
        return 0
    _, blocks = split_blocks(text)
    print("%s" % history_path)
    print("blocks  %d" % len(blocks))
    print("size    %d bytes" % len(text.encode("utf-8")))
    claude = read_text(os.path.join(project, "CLAUDE.md"))
    if claude is None:
        print("pointer no CLAUDE.md")
    else:
        m = re.search(r"^## Last review[ \t]*\r?\n(.*)$", claude, re.M)
        print("pointer %s" % (m.group(1).strip() if m else "no '## Last review' section"))
    return 0


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    sub = p.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("add", help="prepend a dated block and refresh the pointer")
    a.add_argument("project")
    a.add_argument("--date", required=True)
    a.add_argument("--verdict", required=True,
                   choices=["Ready", "Ready with notes", "Not ready"])
    a.add_argument("--model", required=True)
    a.add_argument("--scope", required=True)
    a.add_argument("--result", required=True)
    a.add_argument("--unresolved", default="")
    a.add_argument("--cap-bytes", type=int, default=DEFAULT_CAP_BYTES)
    a.add_argument("--keep", type=int, default=DEFAULT_KEEP)
    a.add_argument("--no-claude-md", action="store_true")
    a.set_defaults(func=cmd_add)

    c = sub.add_parser("check", help="read-only: block count, size, current pointer line")
    c.add_argument("project")
    c.set_defaults(func=cmd_check)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
