#!/usr/bin/env bash
# Tests for the three lifecycle hooks.
#
# Run: bash tests/hooks_test.sh
#
# Every case feeds a synthetic stdin payload whose SHAPE was captured from a real
# 2.1.276 run (see README §Hooks), against a throwaway git repo and a fake HOME that
# lives OUTSIDE it — a log file created inside the repo would count as a dirty file and
# poison the drift counters the hooks read.
#
# HOME is overridden for every hook invocation, so the hooks read the statusline.sh and
# the events.jsonl copied into $fake, never this machine's installed ~/.claude. That is
# what makes the drift assertions below mean something.
set -uo pipefail
cd "$(dirname "$0")/.."
REPO_ROOT=$PWD
H=home/.claude/hooks

pass=0; fail=0
red=$'\033[31m'; grn=$'\033[32m'; rst=$'\033[0m'
ok()   { printf '  OK    %s\n' "$1"; pass=$(( pass + 1 )); }
bad()  { printf '%s  FALLA %s — %s%s\n' "$red" "$1" "$2" "$rst"; fail=$(( fail + 1 )); }
has()  { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no contiene «$2»" ;; esac; }
hasnt(){ case "$3" in *"$2"*) bad "$1" "no debía contener «$2»" ;; *) ok "$1" ;; esac; }

# GNU (Git Bash, Linux) vs BSD (macOS) userland. These tests set and read mtimes, so each
# helper tries the GNU spelling and falls back to the BSD one. Plain `date +%s` instead of
# `printf '%(%s)T'`: the runner must stay bash-3.2 clean so that `/bin/bash tests/...` on a
# Mac exercises the status line's re-exec guard instead of skipping it.
set_mtime() { touch -d "@$1" "$2" 2>/dev/null || touch -t "$(date -r "$1" +%Y%m%d%H%M.%S)" "$2"; }
get_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }
iso_utc()   { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ; }

tmp=$(mktemp -d) || { echo "no se pudo crear tmp"; exit 1; }
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"; fake="$tmp/home"
mkdir -p "$repo" "$fake/.claude/logs" "$fake/.claude/hooks" "$fake/.claude/rules"
cp home/.claude/statusline.sh "$fake/.claude/statusline.sh"
# The hooks read their numbers from here, so the fake HOME needs it too. Copying it (rather
# than pointing at the repo's) is what lets a case below edit it and watch the hook change.
cp home/.claude/rules/thresholds.json "$fake/.claude/rules/thresholds.json"

SID="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
git -C "$repo" init -q
( cd "$repo" && git config user.email t@t && git config user.name t \
  && git config commit.gpgsign false ) >/dev/null 2>&1

run() {                 # run <hook script> <json payload>
  printf '%s' "$2" | HOME="$fake" "$BASH" "$REPO_ROOT/$H/$1" 2>&1
}

# ---------------------------------------------------------------- PostToolUseFailure
echo "log-tool-failure.sh"
LOG="$fake/.claude/logs/tool-failures.jsonl"

fail_payload() {        # fail_payload <command> <is_interrupt>
  jq -nc --arg s "$SID" --arg c "$1" --argjson i "$2" --arg d "$repo" \
    '{session_id:$s, cwd:$d, hook_event_name:"PostToolUseFailure", tool_name:"Bash",
      tool_input:{command:$c, description:"prueba"},
      tool_use_id:"toolu_x", error:"Exit code 42\nls: no such file",
      is_interrupt:$i, duration_ms:322}'
}

run log-tool-failure.sh "$(fail_payload 'ls /nope' false)" >/dev/null
[ -s "$LOG" ] && ok "escribe una línea por fallo" || bad "escribe una línea por fallo" "log vacío"
line=$(tail -1 "$LOG")
has "guarda el código de salida" '"err":"Exit code 42"' "$line"
hasnt "no arrastra stderr al log" "no such file" "$line"
has "guarda el comando" 'ls /nope' "$line"

# A command YOU interrupted is not a failed command.
n_before=$(wc -l < "$LOG")
run log-tool-failure.sh "$(fail_payload 'sleep 999' true)" >/dev/null
n_after=$(wc -l < "$LOG")
[ "$n_before" = "$n_after" ] && ok "ignora los comandos interrumpidos" \
                             || bad "ignora los comandos interrumpidos" "los registró"

# Redaction. These must never land on disk in clear.
run log-tool-failure.sh "$(fail_payload 'curl -H "authorization: Bearer sk-abc123SECRET" x' false)" >/dev/null
line=$(tail -1 "$LOG")
hasnt "redacta el token sk-" "abc123SECRET" "$line"
has  "deja rastro de que redactó" '***' "$line"
run log-tool-failure.sh "$(fail_payload 'deploy --password hunter2plaintext' false)" >/dev/null
hasnt "redacta --password" "hunter2plaintext" "$(tail -1 "$LOG")"
run log-tool-failure.sh "$(fail_payload 'export GITHUB=ghp_AAAABBBBCCCCDDDDEEEE' false)" >/dev/null
hasnt "redacta ghp_" "AAAABBBBCCCCDDDDEEEE" "$(tail -1 "$LOG")"

# Case: a redaction that only matches lowercase is a leak wearing a safety label.
run log-tool-failure.sh "$(fail_payload 'curl -H "Authorization: Bearer tok_UPPERLEAK" x' false)" >/dev/null
hasnt "redacta Authorization en mayúsculas" "UPPERLEAK" "$(tail -1 "$LOG")"
run log-tool-failure.sh "$(fail_payload 'deploy --PASSWORD hunter2UPPER' false)" >/dev/null
hasnt "redacta --PASSWORD en mayúsculas" "hunter2UPPER" "$(tail -1 "$LOG")"
run log-tool-failure.sh "$(fail_payload 'export TOKEN=abc123UPPER' false)" >/dev/null
hasnt "redacta TOKEN= en mayúsculas" "abc123UPPER" "$(tail -1 "$LOG")"
# Dotted keys: the character class must span dots, or only the first segment is hidden.
run log-tool-failure.sh "$(fail_payload 'use sk-proj-AAA.BBB.CCCDOTLEAK here' false)" >/dev/null
hasnt "redacta claves con puntos (sk-proj-a.b.c)" "DOTLEAK" "$(tail -1 "$LOG")"

# ---------------------------------------------------------------- PreCompact
echo
echo "precompact-draft.sh"
printf '%s\n' "primer archivo" > "$repo/a.txt"
( cd "$repo" && git add -A && git commit -qm "trabajo real" ) >/dev/null 2>&1
printf '%s\n' "sin commitear" > "$repo/b.txt"
# Seed the session start so the commit window is known.
jq -nc --arg s "$SID" --arg d "$repo" \
  '{ts:"2000-01-01T00:00:00Z", event:"SessionStart", session:$s, cwd:$d}' \
  >> "$fake/.claude/logs/events.jsonl"

pc=$(jq -nc --arg s "$SID" --arg d "$repo" \
     '{session_id:$s, cwd:$d, hook_event_name:"PreCompact", trigger:"auto"}')
out=$(run precompact-draft.sh "$pc"); rc=$?
[ "$rc" = 0 ] && ok "sale 0 (exit 2 bloquearía la compactación)" \
              || bad "sale 0" "salió $rc"
draft="$repo/docs/handoffs/$(date +%Y-%m-%d)-draft.md"
[ -f "$draft" ] && ok "crea el draft del día" || bad "crea el draft del día" "no existe $draft"
d=$(cat "$draft" 2>/dev/null)
has "dice que NO es un handoff"        "NO es un handoff" "$d"
has "pide explícitamente el criterio"  "Falta la parte de criterio" "$d"
has "trae los commits de la sesión"    "trabajo real" "$d"
has "trae los archivos sin commitear"  "b.txt" "$d"
has "trae el comando que falló"        "ls /nope" "$d"
has "trae la deriva del HANDOFF"       "Deriva del HANDOFF" "$d"

# Two compactions in one day must not overwrite the first.
run precompact-draft.sh "$pc" >/dev/null
n=$(grep -c "Draft automático" "$draft")
[ "$n" = 2 ] && ok "apendea, no pisa (2 compactaciones = 2 bloques)" \
             || bad "apendea, no pisa" "hay $n bloques"

# An unknown session window must say so, never silently mean "all of git log".
pc2=$(jq -nc --arg d "$repo" '{session_id:"no-existe", cwd:$d, hook_event_name:"PreCompact", trigger:"manual"}')
run precompact-draft.sh "$pc2" >/dev/null
has "ventana desconocida se declara" "ventana desconocida" "$(cat "$draft")"

# The draft must never be committable by accident.
if git -C "$REPO_ROOT" check-ignore -q "docs/handoffs/$(date +%Y-%m-%d)-draft.md"; then
  ok "el draft está git-ignored en este repo"
else
  bad "el draft está git-ignored" "git lo commitearía con add -A"
fi

# ---------------------------------------------------------------- SessionStart
echo
echo "session-drift-warn.sh"
ss=$(jq -nc --arg d "$repo" '{session_id:"x", cwd:$d, hook_event_name:"SessionStart", source:"startup"}')

# No HANDOFF, but the repo has commits -> one line, not silence.
out=$(run session-drift-warn.sh "$ss")
has "sin HANDOFF avisa" "no tiene HANDOFF.md" "$out"

# Fresh HANDOFF -> completely silent. This is the property that keeps it readable.
printf '# handoff\n' > "$repo/HANDOFF.md"
( cd "$repo" && git add -A && git commit -qm "handoff" ) >/dev/null 2>&1
now=$(date +%s)
set_mtime "$(( now - 600 ))" "$repo/HANDOFF.md"
set_mtime "$(( now - 900 ))" "$repo/b.txt" 2>/dev/null
out=$(CC_NOW=$now run session-drift-warn.sh "$ss")
[ -z "$out" ] && ok "handoff fresco: silencio absoluto" \
              || bad "handoff fresco: silencio" "dijo: $out"

# Amber drift (a couple of dirty files) -> still silent. Only red interrupts.
for i in 1 2 3; do printf 'x\n' > "$repo/dirty$i.txt"; done
out=$(CC_NOW=$now run session-drift-warn.sh "$ss")
[ -z "$out" ] && ok "deriva ámbar: sigue en silencio" \
              || bad "deriva ámbar: sigue en silencio" "dijo: $out"

# Red drift: >20 dirty files newer than the HANDOFF.
for i in $(seq 4 30); do printf 'x\n' > "$repo/dirty$i.txt"; done
out=$(CC_NOW=$now run session-drift-warn.sh "$ss")
has "deriva ALTA sí avisa" "deriva ALTA" "$out"
has "y dice cómo verificarla" "verify.sh" "$out"

# Red by sessions: 2+ SessionStart since the handoff.
rm -f "$repo"/dirty*.txt
hm=$(get_mtime "$repo/HANDOFF.md")
for k in 1 2; do
  jq -nc --arg d "$repo" --arg t "$(iso_utc "$(( hm + 60 * k ))")" \
    '{ts:$t, event:"SessionStart", session:"s\($t)", cwd:$d}' >> "$fake/.claude/logs/events.jsonl"
done
out=$(CC_NOW=$now run session-drift-warn.sh "$ss")
has "2 sesiones desde el handoff también es rojo" "deriva ALTA" "$out"

# The band comes from rules/thresholds.json and from nowhere else. Raise the sessions
# threshold above what just happened: the same state must stop being red. If this case
# fails, the number went back into the code.
TH="$fake/.claude/rules/thresholds.json"
cp "$TH" "$tmp/th.bak"
jq '(.thresholds[] | select(.id=="handoff-drift-sessions") | .condition.value) = 99'    "$tmp/th.bak" > "$TH"
out=$(CC_NOW=$now run session-drift-warn.sh "$ss")
[ -z "$out" ] && ok "el umbral sale del JSON (subirlo apaga el aviso)"               || bad "el umbral sale del JSON" "siguió avisando: $out"
cp "$tmp/th.bak" "$TH"

# And with no thresholds file there is no red band: silence, never a hardcoded fallback.
mv "$TH" "$tmp/th.gone"
out=$(CC_NOW=$now run session-drift-warn.sh "$ss")
[ -z "$out" ] && ok "sin thresholds.json no inventa banda roja"               || bad "sin thresholds.json no inventa banda roja" "dijo: $out"
mv "$tmp/th.gone" "$TH"

echo
echo "log-event.sh"
# It is wired to several events; the state sweep must fire on SessionEnd and on nothing else.
statedir="$fake/.claude/state"
seed_state() {
  rm -rf "$statedir"; mkdir -p "$statedir"
  : > "$statedir/fresh.json"
  : > "$statedir/viejo.json"
  set_mtime "$(( $(date +%s) - 100000 ))" "$statedir/viejo.json"   # ~27h ago
  : > "$statedir/viejo.txt"                                        # not a snapshot
  set_mtime "$(( $(date +%s) - 100000 ))" "$statedir/viejo.txt"
}
ev() { printf '{"hook_event_name":"%s","session_id":"%s","cwd":"%s"}' "$1" "$SID" "$repo"; }

seed_state
run log-event.sh "$(ev SessionStart)" >/dev/null
[ -f "$statedir/viejo.json" ] && ok "SessionStart no barre nada"                       || bad "SessionStart no barre nada" "borró viejo.json"

seed_state
run log-event.sh "$(ev SessionEnd)" >/dev/null
[ ! -f "$statedir/viejo.json" ] && ok "SessionEnd borra el snapshot de más de 24h"                        || bad "SessionEnd borra el snapshot de más de 24h" "viejo.json sigue ahí"
[ -f "$statedir/fresh.json" ] && ok "SessionEnd conserva el snapshot reciente"                      || bad "SessionEnd conserva el snapshot reciente" "borró fresh.json"
[ -f "$statedir/viejo.txt" ] && ok "SessionEnd solo toca *.json"                     || bad "SessionEnd solo toca *.json" "borró viejo.txt"

# The log line is the hook's actual job: reading stdin twice must not have cost it.
lines=$(grep -c '"event":"SessionEnd"' "$fake/.claude/logs/events.jsonl" 2>/dev/null)
[ "${lines:-0}" -ge 1 ] && ok "sigue escribiendo su línea en events.jsonl"                           || bad "sigue escribiendo su línea en events.jsonl" "no apareció el evento"

# No state directory at all (a machine where the bar never rendered): exit 0, no noise.
rm -rf "$statedir"
out=$(run log-event.sh "$(ev SessionEnd)"); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && ok "sin directorio state/: exit 0 y en silencio"                                 || bad "sin directorio state/: exit 0 y en silencio" "exit $rc, dijo «$out»"

echo
if [ "$fail" -eq 0 ]; then printf '%s%d OK, 0 fallas.%s\n' "$grn" "$pass" "$rst"
else printf '%s%d OK, %d FALLA(S).%s\n' "$red" "$pass" "$fail" "$rst"; fi
exit "$fail"
