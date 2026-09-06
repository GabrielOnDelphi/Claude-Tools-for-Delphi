#!/usr/bin/env python
# Extract a clean plain-text transcript from a YouTube URL (or bare video id).
# Usage:  python extract_transcript.py <url-or-id> [output-dir]
# Default output-dir:  C:\AI\Claude Code\Transcripts
# Prints:  the full path of the written "<title> (transcript).txt"
#
# Why yt-dlp and not WebFetch/browser: YouTube serves captions behind JS, so
# WebFetch cannot read them; the Claude browser extension is often not connected.
# yt-dlp pulls the caption track directly. ffmpeg is NOT required (we parse the
# raw .vtt ourselves; --convert-subs srt is the only step that would need it).

import sys, os, re, io, html, glob, shutil, subprocess, tempfile

TEMP_ROOT = r"C:\AI\Claude Code\Temp"

def run_ytdlp(url, workdir):                              # workdir, NOT the output folder — see main()
    tmpl = os.path.join(workdir, "%(title)s.%(ext)s")
    cmd = [sys.executable, "-m", "yt_dlp",
           "--skip-download", "--write-auto-subs", "--write-subs",
           "--no-playlist",                               # a "watch?v=X&list=Y" link must give ONE video, not the whole list
           "--sub-langs", "en.*,en", "--sub-format", "vtt",
           "--quiet", "--no-warnings", "--no-progress",   # keep stdout clean: only our final path prints
           "-o", tmpl, url]
    # yt-dlp writes the .vtt file(s); a missing-ffmpeg error on --convert is not fatal here.
    return subprocess.run(cmd, check=False).returncode

def pick_vtt(vtts):
    if not vtts:
        return None
    # Prefer a manual English track (".en.vtt") over the auto one (".en-orig.vtt" / "a.en").
    manual = [v for v in vtts if re.search(r"\.en\.vtt$", v)]
    return sorted(manual or vtts)[0]

def to_paragraphs(text, target=500):
    # The caller needs a file it can read in line-sized pieces, so never emit one
    # endless line. Break at sentence ends; auto-captions often carry no punctuation
    # at all, so fall back to a word boundary once the buffer grows past the target.
    # Everything flows through ONE buffer, in order — cutting the incoming piece
    # before flushing what is already buffered would silently reorder the text.
    out, buf = [], ""
    for part in re.split(r"(?<=[.!?])\s+", text):
        buf = (buf + " " + part).strip()
        while len(buf) > target * 2:                      # unpunctuated blob: cut at a space
            cut = buf.rfind(" ", 0, target)
            if cut <= 0: break                            # one word longer than the target: leave it whole
            out.append(buf[:cut]); buf = buf[cut + 1:].strip()
        if len(buf) >= target:
            out.append(buf); buf = ""
    if buf: out.append(buf)
    return "\n\n".join(out)

def vtt_to_text(vtt_path):
    lines = io.open(vtt_path, encoding="utf-8").read().splitlines()
    out = []
    for ln in lines:
        s = ln.strip()
        if not s or s.startswith("WEBVTT") or "-->" in s or s.startswith(("Kind:", "Language:")):
            continue
        s = re.sub(r"<[^>]+>", "", s).strip()          # drop inline <c> / karaoke timing tags
        if s and (not out or out[-1] != s):             # collapse rollup-caption duplicates
            out.append(s)
    text = re.sub(r"\s+", " ", " ".join(out)).strip()
    return html.unescape(text)                          # &gt;&gt; -> >>, &amp; -> & etc.

def main():
    # yt-dlp turns "?" "|" "/" in a video title into full-width ？ ｜ ⧸, and those end
    # up in the path we print. Piped stdout on Windows defaults to cp1252, which cannot
    # encode them: the file would be written and THEN the final print would raise
    # UnicodeEncodeError, handing the caller a non-zero exit for a run that worked.
    for stream in (sys.stdout, sys.stderr):
        try: stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError): pass
    if len(sys.argv) < 2:
        print("ERROR: give a YouTube URL or video id", file=sys.stderr); sys.exit(2)
    url = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else r"C:\AI\Claude Code\Transcripts"
    os.makedirs(outdir, exist_ok=True)
    # Download into a private working folder. Everything in it provably belongs to
    # THIS run, so a leftover .vtt from another video can never be picked up, two
    # runs cannot collide, and a playlist accident stays contained. Note that yt-dlp
    # DELETES and rewrites a subtitle file that already exists (its default is
    # "overwrite related files"), so comparing the output folder before/after would
    # not tell a rewritten file apart from a stale one.
    work = tempfile.mkdtemp(prefix="ytsub-", dir=TEMP_ROOT if os.path.isdir(TEMP_ROOT) else None)
    try:
        rc = run_ytdlp(url, work)
        vtt = pick_vtt(glob.glob(os.path.join(work, "*.vtt")))
        if not vtt:
            if rc != 0:
                # ASCII only: this text gets relayed, and a console in cp1252 mangles non-ASCII.
                print("ERROR: yt-dlp failed (exit %d) - check the URL, the network/firewall, "
                      "and that 'python -m yt_dlp --version' works" % rc, file=sys.stderr)
            else:
                print("ERROR: no English caption track for this video", file=sys.stderr)
            sys.exit(1)
        text = to_paragraphs(vtt_to_text(vtt))
        base = re.sub(r"\.en(-orig)?\.vtt$|\.vtt$", "", os.path.basename(vtt))
        dst = os.path.join(outdir, base + " (transcript).txt")
        io.open(dst, "w", encoding="utf-8").write(text)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print(dst)                                          # last stdout line = the transcript path

if __name__ == "__main__":
    main()
