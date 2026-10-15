#!/usr/bin/env bash
# Tests for the optional module home/.claude/modules/enjambre/ and `sync-to-home.sh --with`.
#
# Run: bash tests/enjambre_module_test.sh   (bash-3.2 clean, so it also runs under macOS /bin/bash)
#
# Everything happens in a throwaway HOME and CLAUDE_CONFIG_DIR: the real ~/.claude is never read
# or written. The payload shape is the PreToolUse stdin the hook receives.
set -uo pipefail
cd "$(dirname "$0")/.."
MOD=home/.claude/modules/enjambre
HOOK=$MOD/hooks/enjambre-ssh-guard.sh

pass=0; fail=0
red=$'\033[31m'; grn=$'\033[32m'; rst=$'\033[0m'
ok()  { printf '  OK    %s\n' "$1"; pass=$(( pass + 1 )); }
bad() { printf '%s  FALLA %s — %s%s\n' "$red" "$1" "$2" "$rst"; fail=$(( fail + 1 )); }

tmp=$(mktemp -d) || { echo "no se pudo crear tmp"; exit 1; }
trap 'rm -rf "$tmp"' EXIT
fake="$tmp/home"; mkdir -p "$fake"
cat > "$tmp/nodes.toml" <<'EOF'
[nodes.here]
host = "local"
[nodes.mac]
host = "mac"
[nodes.box]
host = "caja"
EOF
PROJ='C:\work\some-project'

payload() {             # payload <cwd> <command>
  jq -nc --arg d "$1" --arg c "$2" \
    '{session_id:"aaaaaaaa-bbbb", cwd:$d, hook_event_name:"PreToolUse",
      tool_name:"Bash", tool_input:{command:$c, description:"prueba"}}'
}
run() {                 # run <cwd> <command> [extra env...] -> rc
  local d=$1 c=$2; shift 2
  payload "$d" "$c" | env HOME="$fake" ENJAMBRE_NODES="$tmp/nodes.toml" ENJAMBRE_GUARD_HOSTS= "$@" \
    bash "$HOOK" >/dev/null 2>&1
  rc=$?
}
expect() {              # expect <name> <rc wanted>
  if [ "$rc" = "$2" ]; then ok "$1"; else bad "$1" "exit $rc, esperaba $2"; fi
}

echo "Hook enjambre-ssh-guard (módulo)"
run "$PROJ" 'ssh mac ls';                     expect "bloquea ssh mac (host de nodes.toml)" 2
run "$PROJ" 'ssh otro ls';                    expect "deja pasar ssh otro" 0
run "$PROJ" 'ssh caja uptime';                expect "bloquea un host que solo nodes.toml conoce" 2
run "$PROJ" 'ssh -p 22 user@mac ls';          expect "bloquea con opciones y user@" 2
run "$PROJ" "grep 'ssh mac' docs/";           expect "un grep del texto no es un ssh" 0
run "$PROJ" 'ENJAMBRE_RAW_SSH=1 ssh mac ls';  expect "el bypass deja pasar" 0
run 'C:\work\enjambre' 'ssh mac ls';          expect "dentro del repo enjambre no bloquea" 0
run "$PROJ" 'ssh lab ls' ENJAMBRE_GUARD_HOSTS=lab
expect "ENJAMBRE_GUARD_HOSTS añade hosts" 2
run "$PROJ" 'ssh mac ls' ENJAMBRE_NODES="$tmp/no-existe.toml"
expect "sin nodes.toml ni hosts: no bloquea nada" 0
if grep -q '"raw_ssh":1' "$fake/.claude/logs/events.jsonl" 2>/dev/null; then ok "el bypass queda en el log"
else bad "el bypass queda en el log" "no hay línea raw_ssh"; fi
# Spelled in pieces so this line does not trip the same scan when it runs over the kit.
pers='mac''6|Documents/Port''folio|orques''tador'
if grep -nE "$pers" "$HOOK" "$MOD/rules/kit-enjambre.md" "$MOD/README.md" >/dev/null; then
  bad "el módulo no nombra máquinas ni rutas del owner" "$(grep -nE "$pers" "$HOOK" "$MOD/rules/kit-enjambre.md" "$MOD/README.md" | head -1)"
else ok "el módulo no nombra máquinas ni rutas del owner"; fi

echo
echo "sync-to-home.sh: el módulo solo se instala con --with"
dst="$tmp/claude"
sync() { HOME="$fake" CLAUDE_CONFIG_DIR="$dst" bash sync-to-home.sh "$@" >"$tmp/sync.out" 2>&1; }
sync
rc=$?
[ "$rc" = 0 ] && ok "sin bandera: exit 0" || bad "sin bandera: exit 0" "exit $rc: $(tail -1 "$tmp/sync.out")"
if [ -e "$dst/hooks/enjambre-ssh-guard.sh" ] || [ -e "$dst/rules/kit-enjambre.md" ] || [ -e "$dst/modules" ]; then
  bad "sin bandera no instala nada del módulo" "apareció un archivo del módulo"
else ok "sin bandera no instala nada del módulo"; fi
n=$(jq '[.hooks.PreToolUse[]?.hooks[]?.command | select(test("enjambre-ssh-guard"))] | length' "$dst/settings.json")
[ "$n" = 0 ] && ok "sin bandera: settings.json sin el hook" || bad "sin bandera: settings.json sin el hook" "hay $n"

sync --with enjambre
rc=$?
[ "$rc" = 0 ] && ok "--with enjambre: exit 0" || bad "--with enjambre: exit 0" "exit $rc: $(tail -1 "$tmp/sync.out")"
[ -x "$dst/hooks/enjambre-ssh-guard.sh" ] && ok "instala el hook (ejecutable)" || bad "instala el hook (ejecutable)" "falta"
[ -f "$dst/rules/kit-enjambre.md" ] && ok "instala la regla" || bad "instala la regla" "falta"
[ -e "$dst/README.md" ] && bad "no copia el README del módulo" "copió README.md" || ok "no copia el README del módulo"
n=$(jq '[.hooks.PreToolUse[]?.hooks[]?.command | select(test("enjambre-ssh-guard"))] | length' "$dst/settings.json")
[ "$n" = 1 ] && ok "registra el PreToolUse una vez" || bad "registra el PreToolUse una vez" "hay $n"
others=$(jq '[.hooks | to_entries[] | select(.key != "PreToolUse")] | length' "$dst/settings.json")
[ "${others:-0}" -gt 0 ] && ok "conserva los demás hooks del kit" || bad "conserva los demás hooks del kit" "se perdieron"

jq -S . "$dst/settings.json" > "$tmp/first.json"
sync --with enjambre
n=$(jq '[.hooks.PreToolUse[]?.hooks[]?.command | select(test("enjambre-ssh-guard"))] | length' "$dst/settings.json")
[ "$n" = 1 ] && ok "dos veces: sigue registrado una sola vez" || bad "dos veces: sigue registrado una sola vez" "hay $n"
# The mirror's portable `hooks` key replaces the arrays first and the module appends again, so the
# second run may print MERGED; what must hold is that it ends in the very same file.
if cmp -s "$tmp/first.json" <(jq -S . "$dst/settings.json"); then ok "dos veces: el mismo settings.json"
else bad "dos veces: el mismo settings.json" "difiere de la primera pasada"; fi

sync --with nada
rc=$?
[ "$rc" != 0 ] && ok "un módulo que no existe falla en voz alta" || bad "un módulo que no existe falla en voz alta" "exit 0"

echo
if [ "$fail" = 0 ]; then printf '%s%d OK, 0 fallas.%s\n' "$grn" "$pass" "$rst"; exit 0
else printf '%s%d OK, %d FALLA(S).%s\n' "$red" "$pass" "$fail" "$rst"; exit 1; fi
