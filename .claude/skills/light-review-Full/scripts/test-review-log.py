"""
test-review-log.py - prove review-log.py never splits a block and never goes below the floor.

Run it:  python test-review-log.py
It prints one line per check and exits 1 on the first failure.

The two faults this exists to catch are the ones a model makes by hand when it does the same job:
cutting a block in half at the byte cap, and trimming past the 5-block floor because the file is
still over the cap. Both leave a ReviewHistory.md that still looks plausible.
"""

import importlib.util
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("reviewlog", os.path.join(HERE, "review-log.py"))
rl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rl)

FAILURES = []


def check(name, condition, detail=""):
    if condition:
        print("  ok    %s" % name)
    else:
        print("  FAIL  %s  %s" % (name, detail))
        FAILURES.append(name)


def fresh_project():
    d = tempfile.mkdtemp(prefix="reviewlog-test-")
    with open(os.path.join(d, "CLAUDE.md"), "w", encoding="utf-8") as f:
        f.write("# Test project\n\nSome text.\n")
    return d


def add(project, date, verdict="Ready", **kw):
    argv = ["add", project, "--date", date, "--verdict", verdict,
            "--model", kw.get("model", "Opus 5"),
            "--scope", kw.get("scope", "1 file - Foo.pas"),
            "--result", kw.get("result", "nothing found; compiles clean."),
            "--unresolved", kw.get("unresolved", "")]
    if "cap_bytes" in kw:
        argv += ["--cap-bytes", str(kw["cap_bytes"])]
    if "keep" in kw:
        argv += ["--keep", str(kw["keep"])]
    return rl.main(argv)


def history(project):
    with open(os.path.join(project, rl.HISTORY_NAME), encoding="utf-8") as f:
        return f.read()


def run():
    # 1. First run creates the file with the title and exactly one block.
    print("first run on an empty project")
    p = fresh_project()
    add(p, "2026-01-01")
    t = history(p)
    _, blocks = rl.split_blocks(t)
    check("file starts with the title", t.startswith(rl.HISTORY_TITLE), repr(t[:40]))
    check("one block", len(blocks) == 1, "got %d" % len(blocks))
    check("Unresolved defaults to none", "- **Unresolved:** none" in t)
    shutil.rmtree(p, ignore_errors=True)

    # 2. Newest block goes on top.
    print("newest first")
    p = fresh_project()
    add(p, "2026-01-01")
    add(p, "2026-02-02")
    _, blocks = rl.split_blocks(history(p))
    check("two blocks", len(blocks) == 2, "got %d" % len(blocks))
    check("newest on top", blocks[0].startswith("## 2026-02-02"), blocks[0][:20])
    shutil.rmtree(p, ignore_errors=True)

    # 3. The cap drops WHOLE blocks from the bottom, never half of one.
    print("cap trims whole blocks only")
    p = fresh_project()
    for i in range(1, 13):
        add(p, "2026-%02d-01" % i, cap_bytes=700, keep=2)
    t = history(p)
    _, blocks = rl.split_blocks(t)
    check("trimmed below 12", len(blocks) < 12, "got %d" % len(blocks))
    check("floor of 2 held", len(blocks) >= 2, "got %d" % len(blocks))
    check("every surviving block is whole",
          all(b.startswith("## 20") and "- **Unresolved:**" in b for b in blocks),
          "a block lost its lines")
    check("newest kept, oldest dropped", blocks[0].startswith("## 2026-12-01"), blocks[0][:20])
    check("no orphan fragment above the first block",
          t[:t.index("## 2026")].strip() == rl.HISTORY_TITLE)
    shutil.rmtree(p, ignore_errors=True)

    # 4. The floor beats the cap: 5 blocks survive a cap far too small for them.
    print("floor beats cap")
    p = fresh_project()
    for i in range(1, 9):
        add(p, "2026-%02d-01" % i, cap_bytes=10, keep=5)
    _, blocks = rl.split_blocks(history(p))
    check("exactly the floor survives", len(blocks) == 5, "got %d" % len(blocks))
    check("they are the 5 newest",
          [b.split()[1] for b in blocks] ==
          ["2026-08-01", "2026-07-01", "2026-06-01", "2026-05-01", "2026-04-01"],
          str([b.split()[1] for b in blocks]))
    shutil.rmtree(p, ignore_errors=True)

    # 5. The CLAUDE.md pointer is overwritten, not appended to, and keeps the rest of the file.
    print("CLAUDE.md pointer")
    p = fresh_project()
    add(p, "2026-01-01", verdict="Ready")
    add(p, "2026-02-02", verdict="Not ready")
    with open(os.path.join(p, "CLAUDE.md"), encoding="utf-8") as f:
        c = f.read()
    check("exactly one pointer section", c.count(rl.POINTER_HEADING) == 1,
          "found %d" % c.count(rl.POINTER_HEADING))
    check("pointer carries the latest verdict", "2026-02-02 - **Not ready**" in c)
    check("stale verdict is gone", "2026-01-01 - **Ready**" not in c)
    check("original content survived", "# Test project" in c and "Some text." in c)
    shutil.rmtree(p, ignore_errors=True)

    # 6. A project with no CLAUDE.md still gets its history, and says so.
    print("no CLAUDE.md")
    p = tempfile.mkdtemp(prefix="reviewlog-test-")
    add(p, "2026-01-01")
    check("history written anyway", os.path.isfile(os.path.join(p, rl.HISTORY_NAME)))
    shutil.rmtree(p, ignore_errors=True)

    # 7. A legacy file whose header is not our exact title keeps that header.
    print("legacy header preserved")
    p = fresh_project()
    with open(os.path.join(p, rl.HISTORY_NAME), "w", encoding="utf-8") as f:
        f.write("# Reviews of this project\n\nHand-written note that must survive.\n\n"
                "## 2025-12-01 - Ready\n- **Model:** Opus 4.8\n")
    add(p, "2026-01-01")
    t = history(p)
    check("legacy title kept", t.startswith("# Reviews of this project"), t[:30])
    check("hand-written note kept", "Hand-written note that must survive." in t)
    _, blocks = rl.split_blocks(t)
    check("old block still there", len(blocks) == 2 and blocks[1].startswith("## 2025-12-01"))
    shutil.rmtree(p, ignore_errors=True)

    print("")
    if FAILURES:
        print("%d FAILED: %s" % (len(FAILURES), ", ".join(FAILURES)))
        return 1
    print("all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(run())
