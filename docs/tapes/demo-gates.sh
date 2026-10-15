#!/usr/bin/env bash
# docs/tapes/demo-gates.sh — lane `demo` of tools/lane.sh, for the Mac node (enjambre `tests` job).
#
# Serves docs/demo on 127.0.0.1 and runs docs/tapes/demo-gates.mjs against it: Lighthouse mobile
# (median of 5), axe on five states, the flicker meter, 15 screenshots and the card clip. Then:
#
#   evidence/demo-v2/GATES.md, gates.json, *.png      the gates and the captures (committed)
#   docs/media/demo-preview.mp4 / .webm                the card clip, 1280x720, <= 1.5 MB each
#   docs/media/demo-poster.webp                        its first frame, <= 120 KB
#
# Detached + polled like docs/tapes/media.sh: the first call starts the run in its own session,
# every call waits up to DEMO_POLL_S (100 s), prints the log tail and exits 90 while it still runs.
# Exit codes of the run: 20 missing tool · 21 npm install failed · 22 a gate failed (the report is
# still written) · 23 encode over budget.
set -uo pipefail
cd "$(dirname "$0")/../.."
ST="$(git rev-parse --git-dir)/demo-gates"
OUT=docs/tapes/out/demo-gates
LOG=docs/tapes/out/demo-gates.log
mkdir -p "$ST" "$OUT"

run() {
  set -uo pipefail
  echo "== demo-gates.sh run $(date '+%F %T') on $(uname -sm)"
  export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
  for t in node ffmpeg python3; do
    command -v "$t" >/dev/null || { echo "brew install $t"; brew install "$t" || return 20; }
  done
  node --version; ffmpeg -version | head -1
  local W=docs/tapes/out/gates-node
  mkdir -p "$W"
  if [ ! -d "$W/node_modules/playwright" ]; then
    (cd "$W" && npm init -y >/dev/null && npm i --no-audit --no-fund playwright@1.48.2 @axe-core/playwright@4.10.1 \
      lighthouse@12.2.1 chrome-launcher@1.1.2 jpeg-js@0.4.4) || return 21
  fi
  # perl alarm = a timeout that exists on stock macOS; the 2026-10-15 run hung after this download
  (cd "$W" && perl -e 'alarm shift; exec @ARGV' 900 npx playwright install chromium) || return 21
  echo "== playwright ready"
  cp docs/tapes/demo-gates.mjs "$W/demo-gates.mjs"

  local port=$((18000 + RANDOM % 1000))
  python3 -m http.server "$port" --bind 127.0.0.1 --directory docs/demo >/dev/null 2>&1 &
  local srv=$!
  sleep 1
  echo "== serving docs/demo on :$port"
  rm -rf "$OUT"; mkdir -p "$OUT"
  # Measure what visitors get (gzip, real TLS) when the published files are this commit's files;
  # otherwise the local server (python http.server: no compression, so perf reads lower).
  local base="http://127.0.0.1:$port" live="${DEMO_LIVE_URL:-https://kit.ichisieben.dev}" same=1 f
  for f in index.html app.js content.js grid.json; do
    [ "$(curl -fsS --max-time 20 "$live/${f/index.html/}?gates=$RANDOM" | shasum | cut -c1-40)" = "$(shasum < "docs/demo/$f" | cut -c1-40)" ] || { same=0; echo "live differs: $f"; }
  done
  [ $same = 1 ] && base="$live"
  echo "== measuring $base"
  local rc=0
  (cd "$W" && node demo-gates.mjs "$base" "$OLDPWD/$OUT") || rc=22
  kill "$srv" 2>/dev/null

  mkdir -p evidence/demo-v2
  rm -f evidence/demo-v2/*.png
  cp "$OUT"/*.png "$OUT"/GATES.md "$OUT"/gates.json evidence/demo-v2/ 2>/dev/null

  if [ -f "$OUT/clip.webm" ]; then
    echo "== encode the clip"
    local MAX=1572864 VF="trim=start=1.2,setpts=PTS-STARTPTS,scale=1280:720:flags=lanczos,fps=30,format=yuv420p"
    local COLOR=(-colorspace bt709 -color_primaries bt709 -color_trc iec61966-2-1 -color_range tv) crf ok=0
    mkdir -p docs/media
    for crf in 34 40 46; do
      ffmpeg -v error -y -i "$OUT/clip.webm" -vf "$VF" -an -c:v libvpx-vp9 -crf "$crf" -b:v 0 -row-mt 1 "${COLOR[@]}" docs/media/demo-preview.webm || return 23
      [ "$(wc -c < docs/media/demo-preview.webm)" -le $MAX ] && { ok=1; echo "webm vp9 crf $crf"; break; }
    done
    [ $ok = 1 ] || return 23; ok=0
    for crf in 24 28 32; do
      ffmpeg -v error -y -i "$OUT/clip.webm" -vf "$VF" -an -c:v libx264 -preset slow -profile:v high -crf "$crf" \
        -pix_fmt yuv420p -movflags +faststart "${COLOR[@]}" docs/media/demo-preview.mp4 || return 23
      [ "$(wc -c < docs/media/demo-preview.mp4)" -le $MAX ] && { ok=1; echo "mp4 x264 crf $crf"; break; }
    done
    [ $ok = 1 ] || return 23
    # the frame where the first cause -> effect is complete (red bar, wires, caption); frame 0 is the hero fading in
    ffmpeg -v error -y -ss "${DEMO_POSTER_S:-5.6}" -i docs/media/demo-preview.mp4 -frames:v 1 "$OUT/poster.png" || return 23
    python3 -c 'import PIL' 2>/dev/null || python3 -m pip install --user --quiet pillow || return 23
    python3 - "$OUT/poster.png" docs/media/demo-poster.webp <<'PY' || return 23
import os, sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
for q in (88, 80, 72, 64):
    im.save(sys.argv[2], "WEBP", quality=q, method=6)
    if os.path.getsize(sys.argv[2]) <= 122880: break
else: sys.exit(1)
print("poster webp q", q)
im.resize((640, 360), Image.LANCZOS).save(sys.argv[2].replace(".webp", "-mobile.webp"), "WEBP", quality=80, method=6)
PY
    for f in docs/media/demo-preview.webm docs/media/demo-preview.mp4 docs/media/demo-poster.webp docs/media/demo-poster-mobile.webp; do
      printf '%9s B  %s  ' "$(wc -c < "$f")" "$f"
      ffprobe -v error -select_streams v -show_entries stream=codec_name,width,height,r_frame_rate:format=duration -of csv=p=0 "$f" | tr '\n' ' '; echo
    done
  else
    echo "no clip recorded"; rc=22
  fi
  return $rc
}

alive() { [ -f "$ST/pid" ] && kill -0 "$(cat "$ST/pid")" 2>/dev/null; }

if [ "${1:-}" = --foreground ]; then run; exit $?; fi

head=$(git rev-parse --short HEAD)
# A run older than DEMO_MAX_S (45 min) is hung: kill its session (setsid: pid = pgid) and start over.
if alive && [ -n "$(find "$ST/started" -mmin +"$(( ${DEMO_MAX_S:-2700} / 60 ))" 2>/dev/null)" ]; then
  echo "demo-gates.sh: run from $(cat "$ST/started") is hung, killing it"; kill -TERM -- "-$(cat "$ST/pid")" 2>/dev/null; sleep 3
  rm -f "$ST/started" "$ST/exit"
fi
# Start when nothing runs and there is no finished result for this commit (a stale `started` from a
# dead run used to poll forever at exit 90).
if ! alive && { [ ! -f "$ST/exit" ] || [ "$(cat "$ST/commit" 2>/dev/null)" != "$head" ]; }; then
  date '+%F %T' > "$ST/started"; echo "$head" > "$ST/commit"; rm -f "$ST/exit"; : > "$LOG"
  self="$PWD/docs/tapes/demo-gates.sh"
  KEEP=(); command -v caffeinate >/dev/null && KEEP=(caffeinate -dims)
  nohup perl -MPOSIX=setsid -e 'setsid(); exec @ARGV' \
    ${KEEP[@]+"${KEEP[@]}"} bash -c 'bash "$1" --foreground >> "$2" 2>&1; echo $? > "$3/exit"' _ "$self" "$LOG" "$ST" \
    </dev/null >/dev/null 2>&1 &
  echo $! > "$ST/pid"
  echo "demo-gates.sh: started (log $LOG)"
fi

waited=0
while [ ! -f "$ST/exit" ] && [ $waited -lt "${DEMO_POLL_S:-100}" ]; do sleep 5; waited=$((waited + 5)); done
tail -n 40 "$LOG"
if [ -f "$ST/exit" ]; then
  rc=$(cat "$ST/exit"); echo "demo-gates.sh: finished, exit $rc"; exit "$rc"
fi
echo "demo-gates.sh: still running (exit 90 = not a failure; call again)"
exit 90
