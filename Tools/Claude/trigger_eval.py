#!/usr/bin/env python3
"""Measure whether the light-code-Comments description fires on the right prompts.

Why not skill-creator's own scripts/run_eval.py
-----------------------------------------------
That script writes a STUB command named `<skill>-skill-<random hex>` into
.claude/commands/, runs `claude -p <query>`, and counts a trigger only when that
exact random name appears in a Skill or Read tool call. That works for a skill
that is not installed yet. Ours IS installed: the real `light-code-Comments` sits
in the same listing and competes with the stub. Every time the model picks the
real skill - the likely case, since the real one has a body and the stub does not
- the run is scored "did not trigger", which is a false negative.

So this runner counts a trigger when EITHER name is invoked. Everything else is
the same mechanism: `claude -p` with streamed partial messages, killed as soon as
the first tool call starts, so no query ever does real work on real source.
"""

import json
import os
import queue
import subprocess
import sys
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

SKILL_NAME = "light-code-Comments"
PROJECT_ROOT = Path(r"C:\Users\trei")
EVAL_SET = Path(r"C:\Users\trei\.claude\skills\light-code-Comments\evals\trigger-evals.json")
TIMEOUT = 90


def run_one(query, model):
    """Return True when the model reached for the skill under test."""
    stub = f"{SKILL_NAME}-stub-{uuid.uuid4().hex[:8]}"
    cmd_dir = PROJECT_ROOT / ".claude" / "commands"
    cmd_file = cmd_dir / f"{stub}.md"
    proc = None
    try:
        cmd_dir.mkdir(parents=True, exist_ok=True)
        cmd_file.write_text(
            "---\ndescription: |\n  probe copy of the skill under test\n---\n", encoding="utf-8")

        cmd = ["claude", "-p", query, "--output-format", "stream-json",
               "--verbose", "--include-partial-messages"]
        if model:
            cmd += ["--model", model]
        env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}

        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                cwd=str(PROJECT_ROOT), env=env)

        q = queue.Queue()

        def pump(fd):
            try:
                for chunk in iter(lambda: fd.read(4096), b""):
                    q.put(chunk)
            except Exception:
                pass
            q.put(None)

        threading.Thread(target=pump, args=(proc.stdout,), daemon=True).start()

        buf = ""
        acc = ""
        pending = None
        start = time.time()
        while time.time() - start < TIMEOUT:
            try:
                chunk = q.get(timeout=1)
            except queue.Empty:
                continue
            if chunk is None:
                break
            buf += chunk.decode("utf-8", errors="replace")
            while "\n" in buf:
                line, buf = buf.split("\n", 1)
                if not line.strip():
                    continue
                try:
                    ev = json.loads(line)
                except json.JSONDecodeError:
                    continue

                # partial stream: a tool call is starting
                if ev.get("type") == "stream_event":
                    e = ev.get("event", {})
                    if e.get("type") == "content_block_start":
                        cb = e.get("content_block", {})
                        if cb.get("type") == "tool_use":
                            pending = cb.get("name")
                            acc = ""
                    elif e.get("type") == "content_block_delta" and pending in ("Skill", "Read"):
                        acc += e.get("delta", {}).get("partial_json", "")
                        if SKILL_NAME in acc:
                            return True
                    elif e.get("type") == "content_block_stop" and pending in ("Skill", "Read"):
                        if SKILL_NAME in acc:
                            return True
                        pending = None

                # Full assistant message - the fallback when partial events are absent.
                # Only DECIDE on a message that actually carries a tool call. A first
                # message of plain text ("I'll clean those comments...") is not an
                # answer to the question, and treating it as "did not trigger" scored
                # every such run as a miss.
                if ev.get("type") == "assistant":
                    blocks = ev.get("message", {}).get("content", [])
                    tools = [b for b in blocks if b.get("type") == "tool_use"]
                    if not tools:
                        continue
                    for block in tools:
                        if SKILL_NAME in json.dumps(block.get("input", {})):
                            return True
                        if block.get("name") == "Skill":
                            return False   # it reached for a DIFFERENT skill - a real miss
                    return False
        return False
    finally:
        if proc and proc.poll() is None:
            proc.kill()
        try:
            cmd_file.unlink(missing_ok=True)
        except Exception:
            pass


def main():
    model = sys.argv[1] if len(sys.argv) > 1 else None
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    items = json.loads(EVAL_SET.read_text(encoding="utf-8"))
    if limit:
        items = items[:limit] + items[10:10 + limit]

    results = []
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = {ex.submit(run_one, it["query"], model): it for it in items}
        for f in as_completed(futs):
            it = futs[f]
            try:
                fired = f.result()
            except Exception as exc:
                print(f"ERROR: {exc}", file=sys.stderr)
                fired = False
            ok = (fired == it["should_trigger"])
            results.append((ok, it["should_trigger"], fired, it["query"]))
            print("." if ok else "x", end="", flush=True)

    print("\n")
    pos = [r for r in results if r[1]]
    neg = [r for r in results if not r[1]]
    print(f"should trigger : {sum(1 for r in pos if r[0])}/{len(pos)} fired")
    print(f"should not     : {sum(1 for r in neg if r[0])}/{len(neg)} stayed out")
    print(f"overall        : {sum(1 for r in results if r[0])}/{len(results)}\n")
    for ok, want, got, qry in sorted(results, key=lambda r: r[0]):
        if not ok:
            label = "MISSED (should have fired)" if want else "FALSE FIRE (should have stayed out)"
            print(f"{label}: {qry[:150]}")


if __name__ == "__main__":
    main()
