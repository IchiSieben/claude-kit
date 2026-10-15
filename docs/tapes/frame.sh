#!/usr/bin/env bash
# docs/tapes/frame.sh <ans-dir> <n> — draw ONE status-line state the way an editor does: a dim
# caption at the top, the two bar lines at the bottom of the terminal. Called by the VHS tape
# that docs/tapes/media.sh writes; the bar text itself is the real output of
# home/.claude/statusline.sh for docs/fixtures/<n>-*.json (docs/tapes/render-states.sh --ans).
set -u
dir=$1 n=$2
f=$(ls "$dir"/"$n"-*.ans 2>/dev/null | head -1)
[ -n "$f" ] || { echo "frame.sh: no state $n in $dir"; exit 1; }
case "$n" in
  1) cap="caché caliente: minutos hasta que expira" ;;
  2) cap="caché enfriando: la pista dice qué hacer" ;;
  3) cap="caché fría: el próximo turno reescribe el contexto" ;;
  4) cap="contexto pasado del umbral rojo" ;;
  5) cap="HANDOFF atrasado: archivos más nuevos que él" ;;
  *) cap="" ;;
esac
rows=$(tput lines 2>/dev/null || echo 24)
printf '\033[2J\033[H'
printf '\033[2m  claude-kit · status line · %s/5 · %s\033[0m' "$n" "$cap"
# Park the cursor two rows from the bottom and print the bar without a trailing newline,
# so the terminal never scrolls and the bar sits where Claude Code draws it.
printf '\033[%d;1H' $(( rows - 1 ))
printf '%s' "$(cat "$f")"
