#!/usr/bin/env bash
# docs/tapes/render-states.sh — render the status line from docs/fixtures/*.json into
# docs/img/statusline-<state>.png (one per state) and docs/img/statusline-states.gif.
#
# Nothing here reads a real session: every frame comes from a sanitised fixture piped into
# home/.claude/statusline.sh with a pinned environment, so the images are reproducible and
# can be regenerated whenever the bar changes. Run it from the kit root.
#
#   bash docs/tapes/render-states.sh            PNGs + GIF (needs freeze and Pillow)
#   bash docs/tapes/render-states.sh --ans DIR  only the raw ANSI of each state, into DIR
#                                               (<n>-<label>.ans), for docs/tapes/media.sh
#
# Portable: Git Bash on Windows and macOS (BSD touch/date), python3 or python.
#
# Requires: jq, git, python3 with Pillow, and `freeze` (charmbracelet) — set FREEZE to its
# path if it is not on PATH (a project-local copy under .tools/ is fine; .tools/ is ignored).
#
# Known limit: freeze renders with its bundled JetBrains Mono only (`--font.family` and
# `--font.file` had no effect in 0.2.2 on Windows), and that font has no glyph for `⎇`
# (branch) or `❄` (cold cache), so those two print as a box in these images. The real
# captures in docs/img/statusline-*.png show them as the terminal draws them.
#
# Fixture fields the script overrides at render time:
#   .workspace.current_dir / .cwd  -> a throwaway git repo built here (so git and HANDOFF
#                                     fields render), never a real directory
#   .prompt_cache.expires_at       -> now + TTL_S for the state (the fixture's own value is
#                                     a fixed epoch and would print a TTL of thousands of hours)
set -euo pipefail
cd "$(dirname "$0")/../.."
ANS_DIR=""
[ "${1:-}" = --ans ] && { ANS_DIR=${2:?--ans needs a directory}; mkdir -p "$ANS_DIR"; }
FREEZE="${FREEZE:-freeze}"
if [ -z "$ANS_DIR" ]; then
  command -v "$FREEZE" >/dev/null || { echo "freeze not found; set FREEZE=/path/to/freeze"; exit 1; }
  PY=""
  for p in python3 python; do "$p" -c 'import PIL' 2>/dev/null && { PY=$p; break; }; done
  [ -n "$PY" ] || { echo "no python with Pillow (pip install pillow)"; exit 1; }
fi
ESC=$'\033'
SL=home/.claude/statusline.sh
OUT=docs/img
NOW=$(date +%s)

# The states, in the order the GIF plays them: fixture · label · cache TTL left (s) · drift.
STATES=(
  "1-warm            warm           3540  clean"
  "2-cooling         cooling         240  clean"
  "3-cold            cold              0  clean"
  "4-near-compact    near-compact   2000  clean"
  "5-stale-handoff   stale-handoff  3540  dirty"
)

# Throwaway repo: HANDOFF.md committed, then (for the dirty state) two files newer than it.
# A fake HOME keeps ~/.claude/logs/events.jsonl out of the session counter.
TMP=$(mktemp -d)
FAKEHOME="$TMP/home"; mkdir -p "$FAKEHOME/.claude/logs"
: > "$FAKEHOME/.claude/logs/events.jsonl"   # empty log = 0 sessions, not "?"
REPO="$TMP/demo-project"; mkdir -p "$REPO"
git -C "$REPO" init -q -b main
git -C "$REPO" -c user.name=kit -c user.email=kit@example.invalid commit -q --allow-empty -m init
printf '# HANDOFF\n\nstate: demo\n' > "$REPO/HANDOFF.md"
git -C "$REPO" add HANDOFF.md
git -C "$REPO" -c user.name=kit -c user.email=kit@example.invalid commit -q -m "handoff"
# 7 hours old, spelled for GNU touch (-d @epoch) and BSD touch (-t, macOS).
H7=$((NOW - 25200))
touch -d "@$H7" "$REPO/HANDOFF.md" 2>/dev/null \
  || touch -t "$(date -r "$H7" +%Y%m%d%H%M.%S)" "$REPO/HANDOFF.md"
REPO_WIN=$(cd "$REPO" && pwd -W 2>/dev/null || pwd)   # Windows path if Git Bash, else POSIX

export CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000 CC_BAR_WIDTH=20
export CC_STATE_DIR="$TMP/state"; mkdir -p "$CC_STATE_DIR"
frames=(); n=0
for row in "${STATES[@]}"; do
  n=$((n + 1))
  read -r fx label ttl drift <<<"$row"
  if [ "$drift" = dirty ]; then
    printf 'x\n' > "$REPO/notes.md"; printf 'y\n' > "$REPO/app.py"
  fi
  jq --arg d "$REPO_WIN" --argjson exp $((NOW + ttl)) \
     '.workspace.current_dir=$d | .workspace.project_dir=$d | .cwd=$d | .prompt_cache.expires_at=$exp' \
     "docs/fixtures/$fx.json" > "$TMP/$fx.json"
  CC_NOW=$NOW HOME="$FAKEHOME" CC_NODE=mac CC_ENJ_SUMMARY=/nonexistent \
    bash "$SL" < "$TMP/$fx.json" > "$TMP/$fx.ans"
  if [ -n "$ANS_DIR" ]; then cp "$TMP/$fx.ans" "$ANS_DIR/$n-$label.ans"; continue; fi
  "$FREEZE" --output "$OUT/statusline-$label.png" --theme dracula --font.size 14 \
            --padding 12 --window=false < "$TMP/$fx.ans" >/dev/null
  echo "  $label: $(sed "s/${ESC}\[[0-9;]*m//g" "$TMP/$fx.ans" | head -1 | cut -c1-70)…"
  frames+=("$OUT/statusline-$label.png")
done

if [ -n "$ANS_DIR" ]; then rm -rf "$TMP"; echo "wrote $n states -> $ANS_DIR"; exit 0; fi

# GIF: 1.6 s per frame, looped, downscaled so it stays well under 3 MB.
"$PY" -"${frames[@]}" <<'PY'
import sys
from PIL import Image
frames=[Image.open(p).convert("RGB") for p in sys.argv[1:]]
# Pad every frame to the widest one BEFORE scaling, so the text keeps one size across frames.
W=max(f.width for f in frames); H=max(f.height for f in frames)
bg=frames[0].getpixel((0,0))
padded=[]
for f in frames:
    c=Image.new("RGB",(W,H),bg); c.paste(f,(0,0)); padded.append(c)
w=1600
canvas=[c.resize((w, int(H*w/W)), Image.LANCZOS) for c in padded]
pal=[c.quantize(colors=64, method=Image.MEDIANCUT, dither=Image.NONE) for c in canvas]
pal[0].save("docs/img/statusline-states.gif", save_all=True, append_images=pal[1:],
            duration=1600, loop=0, optimize=True)
import os; print("  gif:", os.path.getsize("docs/img/statusline-states.gif")//1024, "KB")
PY
rm -rf "$TMP"
echo "rendered ${#frames[@]} states -> $OUT"
