#!/usr/bin/env bash
# ~/.claude -> home/.claude (this repo). Copies only what mirror_list names,
# normalises to LF, never deletes. Run it when the live config is the truth.
set -euo pipefail
cd "$(dirname "$0")"
. ./mirror-lib.sh
SRC="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DST="home/.claude"
[ -d "$SRC" ] || { echo "no existe $SRC"; exit 1; }

added=0; updated=0; same=0
while IFS= read -r rel; do
  if [ ! -f "$DST/$rel" ]; then
    copy_lf "$SRC/$rel" "$DST/$rel"; echo "  ADDED    $rel"; added=$((added+1))
  elif same_lf "$SRC/$rel" "$DST/$rel"; then
    same=$((same+1))
  else
    copy_lf "$SRC/$rel" "$DST/$rel"; echo "  UPDATED  $rel"; updated=$((updated+1))
  fi
done < <(mirror_list "$SRC")

# In the repo but no longer in ~/.claude: reported, never removed here.
if [ -d "$DST" ]; then
  while IFS= read -r rel; do
    [ -f "$SRC/$rel" ] || echo "  STALE    $rel (en el repo, no en $SRC; borrar a mano si es a proposito)"
  done < <(mirror_list "$DST")
fi
echo "sync-from-home: $added added, $updated updated, $same unchanged -> $DST"
