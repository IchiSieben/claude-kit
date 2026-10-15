#!/usr/bin/env bash
# docs/tapes/media.sh — lane `media` of tools/lane.sh, for the Mac node (enjambre `tests` job).
#
# Records the five status-line states (docs/fixtures/*.json, the same ones render-states.sh
# uses) in a REAL terminal emulator — VHS drives ttyd + xterm.js, the terminal engine VS Code
# uses — instead of freeze's raster, then encodes the card media and regenerates the PNGs/GIF:
#
#   docs/media/statusline-preview.webm   AV1 (VP9 if this ffmpeg has no AV1), <= 1.5 MB
#   docs/media/statusline-preview.mp4    H.264 high, faststart, <= 1.5 MB
#   docs/media/statusline-poster.webp    frame 0, <= 120 KB
#   docs/img/statusline-*.png + statusline-states.gif   (render-states.sh, freeze)
#
# 1280x720, 60 fps, 5 states x 1.55 s = 7.75 s, meant to loop. Colour tags bt709/sRGB, the
# same flags as the Landing's tools/evidence/_clip.ts. Nothing reads a real session.
#
# Detached + polled, the pattern of the Landing's tools/mac/media.sh: an agent's Bash call is
# cut after a few minutes, so the first call starts run() in its own session and every call
# waits up to MEDIA_POLL_S (100 s), prints the log tail and exits 90 while it still runs.
# Exit codes of the run: 20 missing tool · 21 vhs failed · 22 encode over budget · 23 poster
# over budget · 24 render-states failed.
set -uo pipefail
cd "$(dirname "$0")/../.."
ST="$(git rev-parse --git-dir)/media"      # per-worktree state, never committed
OUT=docs/tapes/out                          # gitignored scratch
LOG=$OUT/media.log
mkdir -p "$ST" "$OUT"

run() {
  set -uo pipefail
  echo "== media.sh run $(date '+%F %T') on $(uname -sm)"
  export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
  command -v brew >/dev/null || { echo "no Homebrew"; return 20; }
  # Tools: vhs (records the terminal; pulls ttyd), freeze (PNG frames for the GIF), ffmpeg,
  # a Nerd Font so the terminal has ⎇ and the powerline glyphs; ❄/⚡ fall back to Apple's.
  for t in vhs ffmpeg; do
    command -v "$t" >/dev/null || { echo "brew install $t"; brew install "$t" || return 20; }
  done
  # freeze: kit-media-3 saw `brew install freeze` report "already installed" while the job's PATH
  # had no `freeze`; kit-media-4 installed charmbracelet/tap/freeze into the Cellar but
  # `opt/freeze` was not linked to it (core and tap both name the formula `freeze`). So: look in
  # the Cellar first, then PATH and brew's prefixes, and accept a binary only if it is Charm's
  # freeze (it has `--window`, which render-states.sh uses).
  find_freeze() {
    local c
    for c in $(ls -d "$(brew --cellar)"/freeze/*/bin/freeze 2>/dev/null | sort -r) \
             "$(command -v freeze 2>/dev/null)" "$(brew --prefix)/bin/freeze" \
             "$(brew --prefix charmbracelet/tap/freeze 2>/dev/null)/bin/freeze"; do
      [ -x "$c" ] || continue
      # Capture first, match after: with pipefail, `freeze --help | grep -q` fails whenever grep
      # exits early and freeze dies of SIGPIPE (kit-media-5 rejected a good binary that way).
      local h; h=$("$c" --help 2>&1 || true)
      case "$h" in *--window*) echo "$c"; return 0 ;; esac
    done
    return 1
  }
  freeze_diag() {  # printed only when no candidate passes, so the next run starts with data
    echo "-- freeze diagnosis"
    brew list --verbose charmbracelet/tap/freeze 2>&1 | head -10
    ls -la "$(brew --cellar)"/freeze/*/bin 2>&1 | head -10
    local c
    for c in $(ls -d "$(brew --cellar)"/freeze/*/bin/freeze 2>/dev/null) "$(command -v freeze 2>/dev/null)"; do
      echo "candidate $c:"; "$c" --help 2>&1 | head -8
    done
  }
  FREEZE=$(find_freeze) || {
    echo "brew install charmbracelet/tap/freeze"
    brew install charmbracelet/tap/freeze || return 20
    FREEZE=$(find_freeze) || { freeze_diag; echo "no Charm freeze in $(brew --cellar)/freeze nor on PATH"; return 20; }
  }
  export FREEZE; echo "freeze: $FREEZE"
  if ! ls "$HOME/Library/Fonts" /Library/Fonts 2>/dev/null | grep -qi 'JetBrainsMonoNerd'; then
    echo "brew install --cask font-jetbrains-mono-nerd-font"
    brew install --cask font-jetbrains-mono-nerd-font || return 20
  fi
  vhs --version; "$FREEZE" --version 2>/dev/null | head -1; ffmpeg -version | head -1

  echo "== states (statusline.sh over docs/fixtures)"
  rm -rf "$OUT/ans"; bash docs/tapes/render-states.sh --ans "$OUT/ans" || return 24

  echo "== record (vhs)"
  local tape=$OUT/statusline.tape n
  {
    echo "Output $OUT/raw.mp4"
    echo 'Set Shell "bash"'
    echo 'Set FontFamily "JetBrainsMono Nerd Font"'
    echo 'Set FontSize 13'
    echo 'Set LineHeight 1.3'
    echo 'Set Width 1280'
    echo 'Set Height 720'
    echo 'Set Padding 36'
    echo 'Set Framerate 60'
    echo 'Set Theme "Dracula"'
    echo 'Set TypingSpeed 0'
    echo 'Set CursorBlink false'
    for n in 1 2 3 4 5; do
      echo 'Hide'
      echo "Type \"bash docs/tapes/frame.sh $OUT/ans $n\""
      echo 'Enter'
      echo 'Sleep 400ms'
      echo 'Show'
      echo 'Sleep 1.55s'
    done
  } > "$tape"
  vhs "$tape" || return 21
  ffprobe -v error -show_entries stream=width,height,r_frame_rate:format=duration -of compact "$OUT/raw.mp4"

  echo "== encode"
  local MAX=1572864 COLOR=(-colorspace bt709 -color_primaries bt709 -color_trc iec61966-2-1 -color_range tv)
  local VF="scale=1280:720:flags=lanczos,fps=60,format=yuv420p,setparams=color_primaries=bt709:color_trc=iec61966-2-1:colorspace=bt709:range=tv"
  mkdir -p docs/media
  local enc="libvpx-vp9" crf ok
  ffmpeg -hide_banner -encoders 2>/dev/null | grep -q ' libaom-av1 ' && enc=libaom-av1
  ffmpeg -hide_banner -encoders 2>/dev/null | grep -q ' libsvtav1 ' && enc=libsvtav1
  ok=0
  for crf in 30 36 42 48 54; do
    case $enc in
      libsvtav1)  a=(-c:v libsvtav1 -preset 5 -crf "$crf") ;;
      libaom-av1) a=(-c:v libaom-av1 -cpu-used 5 -row-mt 1 -crf "$crf" -b:v 0) ;;
      *)          a=(-c:v libvpx-vp9 -crf "$crf" -b:v 0 -row-mt 1 -deadline good -cpu-used 2) ;;
    esac
    ffmpeg -v error -y -i "$OUT/raw.mp4" -vf "$VF" -an "${a[@]}" "${COLOR[@]}" docs/media/statusline-preview.webm || return 22
    [ "$(wc -c < docs/media/statusline-preview.webm)" -le $MAX ] && { ok=1; echo "webm $enc crf $crf"; break; }
  done
  [ $ok = 1 ] || return 22
  ok=0
  for crf in 22 25 28 31 34; do
    ffmpeg -v error -y -i "$OUT/raw.mp4" -vf "$VF" -an -c:v libx264 -preset slow -profile:v high \
      -crf "$crf" -pix_fmt yuv420p -movflags +faststart "${COLOR[@]}" docs/media/statusline-preview.mp4 || return 22
    [ "$(wc -c < docs/media/statusline-preview.mp4)" -le $MAX ] && { ok=1; echo "mp4 x264 crf $crf"; break; }
  done
  [ $ok = 1 ] || return 22

  echo "== poster (frame 0)"
  # Homebrew's ffmpeg has no libwebp encoder (kit-media-2 died here with exit 23), so ffmpeg only
  # extracts frame 0 as PNG and Pillow writes the WebP.
  python3 -c 'import PIL' 2>/dev/null || python3 -m pip install --user --quiet pillow || return 23
  ffmpeg -v error -y -i "$OUT/raw.mp4" -frames:v 1 -vf "scale=1280:720:flags=lanczos" "$OUT/poster.png" || return 23
  python3 - "$OUT/poster.png" docs/media/statusline-poster.webp <<'PY' || return 23
import sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
for q in (90, 82, 74, 66, 58):
    im.save(dst, "WEBP", quality=q, method=6)
    import os
    if os.path.getsize(dst) <= 122880:
        print("poster webp q", q); sys.exit(0)
sys.exit(1)
PY

  echo "== PNGs + GIF (render-states.sh, freeze)"
  python3 -c 'import PIL' 2>/dev/null || python3 -m pip install --user --quiet pillow || return 24
  bash docs/tapes/render-states.sh || return 24

  echo "== sizes"
  for f in docs/media/statusline-preview.webm docs/media/statusline-preview.mp4 docs/media/statusline-poster.webp docs/img/statusline-states.gif; do
    printf '%9s B  %s  ' "$(wc -c < "$f")" "$f"
    ffprobe -v error -select_streams v -show_entries stream=codec_name,width,height,r_frame_rate,color_space,color_primaries,color_transfer -of csv=p=0 "$f" 2>/dev/null | head -1
  done
  return 0
}

alive() { [ -f "$ST/pid" ] && kill -0 "$(cat "$ST/pid")" 2>/dev/null; }

if [ "${1:-}" = --foreground ]; then run; exit $?; fi

if [ ! -f "$ST/started" ] && ! alive; then
  date '+%F %T' > "$ST/started"; rm -f "$ST/exit"; : > "$LOG"
  self="$PWD/docs/tapes/media.sh"
  KEEP=(); command -v caffeinate >/dev/null && KEEP=(caffeinate -dims)
  # perl's setsid: macOS has no setsid(1); the run must outlive this shell and the agent's call.
  nohup perl -MPOSIX=setsid -e 'setsid(); exec @ARGV' \
    ${KEEP[@]+"${KEEP[@]}"} bash -c 'bash "$1" --foreground >> "$2" 2>&1; echo $? > "$3/exit"' _ "$self" "$LOG" "$ST" \
    </dev/null >/dev/null 2>&1 &
  echo $! > "$ST/pid"
  echo "media.sh: started (log $LOG)"
fi

waited=0
while [ ! -f "$ST/exit" ] && [ $waited -lt "${MEDIA_POLL_S:-100}" ]; do sleep 5; waited=$((waited + 5)); done
tail -n 25 "$LOG"
if [ -f "$ST/exit" ]; then
  rc=$(cat "$ST/exit"); echo "media.sh: finished, exit $rc"; exit "$rc"
fi
echo "media.sh: still running (exit 90 = not a failure; call again)"
exit 90
