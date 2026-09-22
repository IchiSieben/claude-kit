#!/usr/bin/env bash
# SessionStart -> say it out loud when HANDOFF.md has drifted far from reality.
#
# SessionStart stdout IS added to the session context (confirmed), which is how this
# reaches you at all. So it has to earn its tokens: it prints NOTHING unless the drift is
# in the red band, because a warning that shows on every single startup is a warning
# nobody reads by the third day.
#
# Neither half is defined here. `statusline.sh --drift` is the one definition of drift,
# shared with the bar, and the two numbers that make drift RED come from
# rules/thresholds.json (handoff-drift-files, handoff-drift-sessions) — the same file the
# bar reads. This hook only decides when the red band is worth interrupting you for.
# No thresholds file means no red band: staying silent is the honest failure here, because
# a hardcoded fallback is exactly the duplicate this file was carrying before.
set -u

payload=$(cat 2>/dev/null) || payload=""
cwd=""
if command -v jq >/dev/null 2>&1; then
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
fi
[ -n "$cwd" ] || cwd=$PWD
dir=${cwd//\\//}

sl="$HOME/.claude/statusline.sh"
[ -f "$sl" ] || exit 0

read -r state hage f c s < <(bash "$sl" --drift "$dir" 2>/dev/null) || exit 0
[ -n "${state:-}" ] || exit 0

num() { [ "$1" != "?" ] && [ -n "$1" ]; }

case "$state" in
  ok) exit 0 ;;                                  # fresh: nothing to say
  none)
    # No HANDOFF at all, but only worth mentioning in a repo that has commits — an empty
    # scratch directory does not need to be nagged about session memory.
    git -C "$dir" rev-parse --verify -q HEAD >/dev/null 2>&1 || exit 0
    printf 'AVISO DE ARRANQUE: este repo no tiene HANDOFF.md. Si la sesión va a durar, '
    printf 'proponé /handoff antes de cerrarla.\n'
    exit 0 ;;
esac

th="${HOME:-}/.claude/rules/thresholds.json"
command -v jq >/dev/null 2>&1 && [ -r "$th" ] || exit 0
read -r fop fval sop sval < <(jq -r '
  def cond($id): (.thresholds[]? | select(.id == $id) | .condition);
  [ (cond("handoff-drift-files")    | .op, (.value|tostring)),
    (cond("handoff-drift-sessions") | .op, (.value|tostring)) ] | join(" ")' "$th" 2>/dev/null) || exit 0
# jq.exe (native Windows) ends its line with CRLF and `read` only eats the LF, so the
# last field arrives with a trailing CR that `[ -ge ]` rejects as a non-integer.
sval=${sval%$'\r'}; fval=${fval%$'\r'}; sop=${sop%$'\r'}; fop=${fop%$'\r'}
[ -n "${fval:-}" ] && [ -n "${sval:-}" ] || exit 0

over() {                    # over <measured> <op> <threshold>
  case "$2" in
    '>=') [ "$1" -ge "$3" ] ;;
    '>')  [ "$1" -gt "$3" ] ;;
    '<=') [ "$1" -le "$3" ] ;;
    '<')  [ "$1" -lt "$3" ] ;;
    *)    return 1 ;;
  esac
}

red=0
num "$f" && over "$f" "$fop" "$fval" && red=1
num "$s" && over "$s" "$sop" "$sval" && red=1
(( red )) || exit 0

printf 'AVISO DE ARRANQUE: HANDOFF.md tiene deriva ALTA (%s desde que se escribió; ' "$hage"
printf '%s archivo(s) sucio(s) más nuevo(s), %s commit(s), %s sesión(es) desde entonces).\n' "$f" "$c" "$s"
printf 'El estado escrito quedó muy atrás de lo que realmente pasó. Antes de planificar '
printf 'sobre él, verificalo: `bash verify.sh` si el repo lo tiene, y actualizalo con /handoff.\n'
printf 'Un HANDOFF que afirma algo falso es peor que no tener ninguno.\n'
exit 0
