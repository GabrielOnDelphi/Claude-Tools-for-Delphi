"""
Recolor-ClaudeIcon-EffortTints.py
=================================

Recolors the Claude tray/app icon into effort-level tints.

Source is the untouched terracotta original (claude.ico). Nothing here overwrites
the source; every output is a new file. Pillow only -> run:  python <thisfile>

What it produces (in ICON_DIR):
  - claudeRed1.ico .. claudeRed5.ico : red ramp for the 5 effort levels
                                       (Red1 = strongest red, Red5 = mildest)
  - claudeBlue.ico                   : single blue variant for Fable (R<->B channel swap)
  - claudeBlue1.ico .. claudeBlue5.ico : blue ramp for Fable's 5 effort levels
                                         (Blue1 = strongest blue, Blue5 = mildest)

Reuse / retune:
  - Edit ICON_DIR / SRC below if paths change.
  - Edit RED_LEVELS to reshape the ramp: each row is (R_MUL, R_ADD, G_MUL, B_MUL).
    Higher R_MUL/R_ADD and lower G_MUL/B_MUL  = more red.
  - make_blue() swaps the R and B channels; for a blue *ramp* mirror RED_LEVELS
    onto the blue channel the same way.
"""

from collections import Counter
from PIL import Image

ICON_DIR = r"c:\AI\Claude Code"
SRC      = ICON_DIR + r"\claude.ico"     # clean, unmodified terracotta original

# 5 steps for the 5 effort levels. Step 1 = strongest red, step 5 = mildest.
# (R_MUL, R_ADD, G_MUL, B_MUL)
RED_LEVELS = [
    (1.14, 14, 0.80, 0.74),   # claudeRed1 - most red
    (1.11, 11, 0.84, 0.79),   # claudeRed2
    (1.08,  8, 0.88, 0.84),   # claudeRed3
    (1.05,  5, 0.92, 0.89),   # claudeRed4
    (1.03,  3, 0.96, 0.94),   # claudeRed5 - least red
]


def _dominant(im):
    c = Counter(p[:3] for p in im.get_flattened_data() if p[3] > 10)
    return c.most_common(1)[0][0]


def _load():
    return Image.open(SRC).convert("RGBA")


def _save(im, out):
    im.save(out, format="ICO", sizes=[im.size])
    print("wrote", out, "dominant", _dominant(im))


def make_red_ramp():
    for i, (rm, ra, gm, bm) in enumerate(RED_LEVELS, start=1):
        im = _load()
        px = im.load()
        w, h = im.size
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                px[x, y] = (min(255, int(r * rm + ra)), max(0, int(g * gm)), max(0, int(b * bm)), a)
        _save(im, rf"{ICON_DIR}\claudeRed{i}.ico")


def make_blue():
    im = _load()
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            px[x, y] = (b, g, r, a)          # swap R<->B: terracotta -> blue
    _save(im, rf"{ICON_DIR}\claudeBlue.ico")


def make_blue_ramp():
    # Same ramp shape as RED_LEVELS but applied to the blue channel, after the
    # R<->B swap. (B_MUL/B_ADD boost blue; G_MUL/R_MUL ease off the rest.)
    for i, (bm, ba, gm, rm) in enumerate(RED_LEVELS, start=1):
        im = _load()
        px = im.load()
        w, h = im.size
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                r, b = b, r                  # swap R<->B: terracotta -> blue
                px[x, y] = (max(0, int(r * rm)), max(0, int(g * gm)), min(255, int(b * bm + ba)), a)
        _save(im, rf"{ICON_DIR}\claudeBlue{i}.ico")


if __name__ == "__main__":
    make_red_ramp()
    make_blue()
    make_blue_ramp()
