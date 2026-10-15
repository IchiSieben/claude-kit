#!/usr/bin/env bash
# home/.claude (this repo) -> ~/.claude. Backs up every file it replaces into
# ~/.claude.bak-<timestamp>/, normalises to LF, marks .sh executable, and MERGES
# settings.json instead of overwriting it: only the portable keys travel, so each
# machine keeps its own plugins, marketplaces, MCPs, theme and notifications.
# Never deletes.
#
# Optional modules (home/.claude/modules/<name>/) are NOT part of the mirror: they install only
# when asked, `--with <name>` (repeatable). Without the flag nothing under modules/ is touched.
#   --with enjambre   hooks/enjambre-ssh-guard.sh + rules/kit-enjambre.md + its PreToolUse entry
set -euo pipefail
cd "$(dirname "$0")"
MODULES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --with) [ -n "${2:-}" ] || { echo "--with necesita un nombre de módulo"; exit 1; }
            MODULES+=("$2"); shift 2 ;;
    --with=*) MODULES+=("${1#--with=}"); shift ;;
    *) echo "argumento desconocido: $1 (uso: sync-to-home.sh [--with <módulo>]...)"; exit 1 ;;
  esac
done
. ./mirror-lib.sh
SRC="home/.claude"
DST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
command -v jq >/dev/null || {
  echo "jq no esta en PATH. Windows: winget install jqlang.jq | macOS: brew install jq | Linux: sudo apt install jq"
  exit 1
}
[ -d "$SRC" ] || { echo "no existe $SRC; corre esto desde la raiz del repo"; exit 1; }

TS=$(date +%Y%m%d-%H%M%S)
BAK="$DST.bak-$TS"
mkdir -p "$DST"
added=0; updated=0; same=0; merged=0
backup() { mkdir -p "$BAK/$(dirname "$1")"; cp "$DST/$1" "$BAK/$1"; }

while IFS= read -r rel; do
  if [ "$rel" = settings.json ] && [ -f "$DST/$rel" ]; then
    tmp="$DST/settings.json.tmp"
    # Deep merge: repo wins on the portable keys, home keeps everything else.
    jq -s --argjson keys "$PORTABLE" \
      '.[0] * (.[1] | with_entries(select(.key as $k | $keys | index($k))))' \
      "$DST/$rel" "$SRC/$rel" > "$tmp"
    jq -e . "$tmp" >/dev/null || { echo "  ERROR    settings.json fusionado no es JSON valido; no se toca"; rm -f "$tmp"; exit 1; }
    if cmp -s <(jq -S . "$tmp") <(jq -S . "$DST/$rel"); then
      rm -f "$tmp"; same=$((same+1))
    else
      backup "$rel"; mv "$tmp" "$DST/$rel"
      echo "  MERGED   $rel (claves portables: $(echo "$PORTABLE" | jq -r 'join(", ")'))"; merged=$((merged+1))
    fi
    continue
  fi
  if [ ! -f "$DST/$rel" ]; then
    copy_lf "$SRC/$rel" "$DST/$rel"; echo "  ADDED    $rel"; added=$((added+1))
  elif same_lf "$SRC/$rel" "$DST/$rel"; then
    same=$((same+1))
  else
    backup "$rel"; copy_lf "$SRC/$rel" "$DST/$rel"; echo "  UPDATED  $rel"; updated=$((updated+1))
  fi
  case "$rel" in *.sh) chmod +x "$DST/$rel" ;; esac
done < <(mirror_list "$SRC")

# visor.py lives outside ~/.claude: the visor skill falls back to
# $HOME/claude-archive/visor.py, so the skill is broken without it.
ARCHIVE="$HOME/claude-archive"
if [ ! -f "$ARCHIVE/visor.py" ]; then
  copy_lf visor.py "$ARCHIVE/visor.py"; echo "  ADDED    claude-archive/visor.py"; added=$((added+1))
elif same_lf visor.py "$ARCHIVE/visor.py"; then
  same=$((same+1))
else
  mkdir -p "$BAK/claude-archive"; cp "$ARCHIVE/visor.py" "$BAK/claude-archive/visor.py"
  copy_lf visor.py "$ARCHIVE/visor.py"; echo "  UPDATED  claude-archive/visor.py"; updated=$((updated+1))
fi

# ---- optional modules: files copied like the mirror (backup, LF, +x); a settings.json in the
# module is APPENDED to the hook arrays, never merged over them, and only when that exact
# command is not registered yet, so running it twice adds nothing.
for mod in ${MODULES[@]+"${MODULES[@]}"}; do
  MSRC="$SRC/modules/$mod"
  [ -d "$MSRC" ] || { echo "no existe el módulo $mod ($MSRC)"; exit 1; }
  while IFS= read -r f; do
    rel=${f#"$MSRC"/}
    [ "$rel" = settings.json ] || [ "$rel" = README.md ] && continue
    if [ ! -f "$DST/$rel" ]; then
      copy_lf "$f" "$DST/$rel"; echo "  ADDED    $rel (módulo $mod)"; added=$((added+1))
    elif same_lf "$f" "$DST/$rel"; then
      same=$((same+1))
    else
      backup "$rel"; copy_lf "$f" "$DST/$rel"; echo "  UPDATED  $rel (módulo $mod)"; updated=$((updated+1))
    fi
    case "$rel" in *.sh) chmod +x "$DST/$rel" ;; esac
  done < <(find "$MSRC" -type f | sort)
  if [ -f "$MSRC/settings.json" ]; then
    [ -f "$DST/settings.json" ] || echo '{}' > "$DST/settings.json"
    tmp="$DST/settings.json.tmp"
    jq -s '.[0] as $h | .[1].hooks as $m
           | reduce ($m | keys[]) as $ev ($h;
               reduce $m[$ev][] as $entry (.;
                 ([$entry.hooks[].command] - [(.hooks[$ev] // [])[].hooks[]?.command]) as $new
                 | if ($new | length) == 0 then .
                   else .hooks[$ev] = ((.hooks[$ev] // []) + [$entry]) end))' \
      "$DST/settings.json" "$MSRC/settings.json" > "$tmp"
    jq -e . "$tmp" >/dev/null || { echo "  ERROR    settings.json con el módulo $mod no es JSON valido; no se toca"; rm -f "$tmp"; exit 1; }
    if cmp -s <(jq -S . "$tmp") <(jq -S . "$DST/settings.json"); then
      rm -f "$tmp"; same=$((same+1))
    else
      backup settings.json; mv "$tmp" "$DST/settings.json"
      echo "  MERGED   settings.json (hooks del módulo $mod)"; merged=$((merged+1))
    fi
  fi
done

echo "sync-to-home: $added added, $updated updated, $merged merged, $same unchanged -> $DST"
[ -d "$BAK" ] && echo "respaldos de lo reemplazado en: $BAK" || true
