"""docs/tapes/build-term-font.py — one static TTF for freeze: JetBrains Mono + the bar's symbols.

freeze takes a single --font.file and has no fallback chain, so ⎇ and ❄ printed as boxes in the
PNGs/GIF. This merges the demo's own fonts (docs/demo/fonts: JetBrains Mono latin, OFL; the two
DejaVu subsets, Bitstream Vera licence) into docs/tapes/fonts/KitMono-Regular.ttf: the variable
JetBrains Mono pinned at wght 400, the DejaVu glyphs scaled from 2048 to 1000 units per em.

    python docs/tapes/build-term-font.py        (needs fontTools + brotli)
"""
import os, sys
from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.merge import Merger

here = os.path.dirname(os.path.abspath(__file__))
demo = os.path.join(here, "..", "demo", "fonts")
tmp = os.path.join(here, "fonts")
parts = []
base = instantiateVariableFont(TTFont(os.path.join(demo, "jetbrains-mono-latin-wght-normal.woff2")), {"wght": 400})
base.flavor = None
for t in ("STAT", "fvar", "gvar", "avar", "HVAR", "MVAR"):
    if t in base: del base[t]
parts.append(base)
for name in ("kit-symbols-mono.woff2", "kit-symbols-branch.woff2"):
    f = TTFont(os.path.join(demo, name)); f.flavor = None
    for t in ("MATH", "GSUB", "GPOS", "GDEF", "kern"):  # glyphs only; Merger cannot merge MATH
        if t in f: del f[t]
    scale_upem(f, 1000)
    parts.append(f)
paths = []
for i, f in enumerate(parts):
    p = os.path.join(tmp, f"_part{i}.ttf"); f.save(p); paths.append(p)
merged = Merger().merge(paths)
for rec in merged["name"].names:
    if rec.nameID in (1, 4, 16): rec.string = "Kit Mono"
    if rec.nameID == 6: rec.string = "KitMono-Regular"
out = os.path.join(tmp, "KitMono-Regular.ttf")
merged.save(out)
for p in paths: os.remove(p)
cmap = TTFont(out).getBestCmap()
missing = [c for c in "▓░┋⎇⚡❄⚠↑↓●✓⊘·→" if ord(c) not in cmap]
print(f"{out}: {os.path.getsize(out)} B, missing: {missing or 'none'}")
sys.exit(1 if missing else 0)
