#!/usr/bin/env bash
# PreCompact -> docs/handoffs/<fecha>-draft.md
#
# This hook collects FACTS ONLY. It deliberately does not write "where we are and why" —
# that is judgment, it is the part that makes a handoff worth reading, and a plausible
# machine-written paragraph there would be worse than a blank one, because it would look
# like someone had thought about it.
#
# Two contract facts, both confirmed against the docs before this was written:
#   - PreCompact stdout goes to the DEBUG LOG only. It is not shown and not injected.
#     So the "you still owe the judgment part" notice goes INSIDE the draft, and
#     compact-reinject.sh (SessionStart/compact) is what surfaces it afterwards.
#   - PreCompact exit code 2 BLOCKS compaction. This script must always exit 0; a draft
#     that fails to write must never cost you a compaction.
#
# stdin: session_id, cwd, hook_event_name, transcript_path, trigger (manual|auto), ...
set -u

payload=$(cat 2>/dev/null) || payload=""
command -v jq >/dev/null 2>&1 || exit 0

cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
sid=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
trg=$(printf '%s' "$payload" | jq -r '.trigger // "?"' 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD
dir=${cwd//\\//}
[ -d "$dir" ] || exit 0

root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || root="$dir"
out="$root/docs/handoffs/$(date +%Y-%m-%d)-draft.md"
mkdir -p "$(dirname "$out")" 2>/dev/null || exit 0

# When did this session start? From the hook log, matched on session_id. If it is not
# there, the window is UNKNOWN — say so, never silently fall back to "all of git log".
since=""
ev="$HOME/.claude/logs/events.jsonl"
if [ -n "$sid" ] && [ -r "$ev" ]; then
  since=$(grep -F "\"session\":\"$sid\"" "$ev" 2>/dev/null \
          | jq -rs '[.[] | select(type=="object" and .event=="SessionStart") | .ts]
                    | sort | first // empty' 2>/dev/null)
  since=${since%$'\r'}
fi

{
  printf '\n## Draft automático — %s (compact: %s, sesión %s)\n\n' \
         "$(date +%Y-%m-%d\ %H:%M)" "$trg" "${sid:0:8}"
  printf '> Esto NO es un handoff. Son los hechos que el hook pudo juntar solo.\n'
  printf '> **Falta la parte de criterio**: dónde estamos, por qué, qué se decidió y qué\n'
  printf '> sigue. Eso lo escribís vos o `/handoff` — no lo inventa el hook.\n\n'

  printf '**Rama:** %s\n\n' "$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"

  printf '**Commits de la sesión'
  if [ -n "$since" ]; then printf ' (desde %s):**\n\n' "$since"
  else printf ':** _ventana desconocida — no hay SessionStart para esta sesión en el log de hooks_\n\n'; fi
  if [ -n "$since" ]; then
    n=$(git -C "$dir" log --since="$since" --oneline 2>/dev/null | wc -l)
    if [ "${n:-0}" -gt 0 ]; then git -C "$dir" log --since="$since" --format='- `%h` %s' 2>/dev/null
    else printf -- '- (ninguno)\n'; fi
  fi
  printf '\n'

  printf '**Archivos sin commitear ahora:**\n\n'
  st=$(git -C "$dir" status --short 2>/dev/null)
  if [ -n "$st" ]; then printf '%s\n' "$st" | sed 's/^/- `/; s/$/`/'
  else printf -- '- (el árbol está limpio)\n'; fi
  printf '\n'

  printf '**Comandos que fallaron en esta sesión:**\n\n'
  fl="$HOME/.claude/logs/tool-failures.jsonl"
  if [ -n "$sid" ] && [ -r "$fl" ]; then
    rows=$(grep -F "\"session\":\"$sid\"" "$fl" 2>/dev/null \
           | jq -rs '.[] | select(type=="object") | "- `\(.err // "?")` — `\(.cmd // "?")`"' 2>/dev/null)
    if [ -n "$rows" ]; then printf '%s\n' "$rows"
    else printf -- '- (ninguno registrado)\n'; fi
  else
    printf -- '- _sin datos: falta `logs/tool-failures.jsonl` (hook `PostToolUseFailure`)_\n'
  fi
  printf '\n'

  printf '**Deriva del HANDOFF en este momento:** `%s`\n\n' \
         "$(bash "$HOME/.claude/statusline.sh" --drift "$dir" 2>/dev/null || echo '?')"
  printf -- '---\n'
} >> "$out" 2>/dev/null

exit 0
