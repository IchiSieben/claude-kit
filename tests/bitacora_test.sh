#!/usr/bin/env bash
# tests/bitacora_test.sh — bitacora.py against a fake root (never reads the real home).
# Replaces the SPEC's `pytest` line on purpose: the kit's build copies only tests/*.sh.
set -uo pipefail
cd "$(dirname "$0")/.."
pass=0 fail=0
ok()  { printf '  OK    %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FALLA %s — %s\n' "$1" "$2"; fail=$((fail + 1)); }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1" "${3:-condición falsa}"; fi; }

# python chosen by RUNNING it (on Windows python3 can be the Store stub).
PY=""
for c in python3 python; do
  if "$c" -c 'import sys' >/dev/null 2>&1; then PY=$c; break; fi
done
[ -n "$PY" ] || { echo "sin python"; exit 1; }

T=$(mktemp -d) || exit 1
[ -n "${KEEP:-}" ] || trap 'rm -rf "$T"' EXIT
R="$T/root"; A="$T/archive"; C="$T/claude"; O="$T/out"; V="$T/novisor"
mkdir -p "$R" "$A" "$C"
NOW="2026-10-15T12:00:00+00:00"
GIT_ENV="GIT_AUTHOR_NAME=zz GIT_AUTHOR_EMAIL=zz@example.invalid GIT_COMMITTER_NAME=zz GIT_COMMITTER_EMAIL=zz@example.invalid"

mkrepo() { # name date
  mkdir -p "$R/$1"
  ( cd "$R/$1" && git init -q . && echo x > f.txt && git add f.txt \
    && env $GIT_ENV GIT_AUTHOR_DATE="$2" GIT_COMMITTER_DATE="$2" git commit -q -m "commit of $1" ) 2>/dev/null
}
mkrepo alpha "2026-10-10T12:00:00+00:00"
mkrepo beta  "2026-08-01T12:00:00+00:00"
mkrepo d90   "2026-07-17T12:00:00+00:00"
mkrepo d91   "2026-07-16T12:00:00+00:00"
mkrepo d14   "2026-10-01T12:00:00+00:00"
mkrepo d15   "2026-09-30T12:00:00+00:00"
printf '# alpha\n\n## Estado\n- IN PROGRESS: terminar el widget\n' > "$R/alpha/HANDOFF.md"
echo dirty > "$R/alpha/untracked.txt"
( cd "$R/alpha" && git remote add origin git@github.com:zz-tester/alpha.git \
  && git worktree add -q ../alpha-wt -b wt-branch ) 2>/dev/null
mkdir -p "$R/plain" "$R/_scratch" "$R/node_modules"
printf '# plain\n\nPrimera línea útil sin palabra clave\n' > "$R/plain/HANDOFF.md"
printf '# s\n' > "$R/_scratch/HANDOFF.md"

cat > "$T/projects.toml" <<'EOF'
[[project]]
name = "alpha"
path = "alpha"
repo = "https://github.com/zz-tester/alpha.git"
domain = "alpha.example.invalid"
drive = "remote:demo/alpha"

[[project]]
name = "ghost"
path = "no-existe"
EOF

if command -v cygpath >/dev/null 2>&1; then NATIVE=$(cygpath -w "$R"); RN=$(cygpath -m "$R"); else NATIVE="$R"; RN="$R"; fi
ENC=$(printf '%s' "$NATIVE" | sed 's/[:\\/._ ]/-/g')
cat > "$C/history.jsonl" <<EOF
{"display":"prompt secreto del hilo alpha","timestamp":1760443200000,"project":"$RN/alpha","sessionId":"s1"}
{"display":"otro prompt fuera de todo","timestamp":1760443200000,"project":"/home/zz-tester/otro","sessionId":"s2"}
EOF
cat > "$A/sessions.json" <<EOF
[{"session_id":"a","project":"$ENC-alpha","first_seen":"2026-10-09T10:00:00Z","last_seen":"2026-10-10T10:00:00Z",
  "models":{"m":{"requests":1,"input":1000,"output":500,"cache_read":0,"cache_write":0,"cost_usd":1.5}}},
 {"session_id":"b","project":"$ENC-plain","first_seen":"2026-10-01T12:00:00Z","last_seen":"2026-10-01T12:00:00Z","models":{}}]
EOF

B() { "$PY" bitacora.py --root "$R" --projects "$T/projects.toml" --claude-dir "$C" --archive "$A" \
      --visor-dir "$V" --now "$NOW" "$@"; }

echo "bitacora: fixture en tmp (7 repos, 1 worktree, 1 sin git)"

# dry-run
B --dry-run --out "$O" > "$T/dry.txt" 2>&1
check "dry-run: sale 0 y lista proyectos y fuentes" "grep -q 'alpha' '$T/dry.txt' && grep -q 'history.jsonl' '$T/dry.txt'"
check "dry-run: no escribe nada" "[ ! -e '$O' ] && [ ! -e '$A/bitacora.html' ]"

# real run
B --out "$O" > "$T/run1.txt" 2>&1 || bad "generación" "$(tail -3 "$T/run1.txt")"
check "genera bitacora.html y bitacora.json" "[ -s '$O/bitacora.html' ] && [ -s '$O/bitacora.json' ]"

J="$O/bitacora.json"; H="$O/bitacora.html"
q() { "$PY" -c "import json,sys;d=json.load(open(sys.argv[1],encoding='utf-8'));$2" "$J"; }
check "repo sin HANDOFF.md aparece como 'sin handoff'" "q x 'sys.exit(0 if [p for p in d[\"projects\"] if p[\"name\"]==\"beta\" and not p[\"handoff\"][\"present\"]] else 1)' && grep -q 'sin handoff' '$H'"
check "HANDOFF: línea IN PROGRESS extraída" "q x 'sys.exit(0 if [p for p in d[\"projects\"] if p[\"name\"]==\"alpha\" and p[\"handoff\"][\"line\"].startswith(\"IN PROGRESS: terminar\")] else 1)'"
check "carpeta sin git (solo HANDOFF) presente" "q x 'sys.exit(0 if [p for p in d[\"projects\"] if p[\"name\"]==\"plain\" and not p[\"git\"][\"present\"] and p[\"handoff\"][\"present\"]] else 1)'"
check "HANDOFF sin palabra clave: primera línea no-heading" "q x 'sys.exit(0 if [p for p in d[\"projects\"] if p[\"name\"]==\"plain\" and p[\"handoff\"][\"line\"].startswith(\"Primera línea\")] else 1)'"
check "worktree plegado en la tarjeta del repo principal" "q x 'sys.exit(0 if (not [p for p in d[\"projects\"] if p[\"name\"]==\"alpha-wt\"]) and [p for p in d[\"projects\"] if p[\"name\"]==\"alpha\" and p[\"worktrees\"]==[\"alpha-wt\"]] else 1)' && grep -q 'worktrees: alpha-wt' '$H'"
check "_scratch y node_modules ausentes" "! grep -q '_scratch\|node_modules' '$H'"
check "entrada de projects.toml sin carpeta listada, sin tarjeta" "grep -q 'en projects.toml pero no en disco' '$H' && grep -q 'no-existe' '$H' && q x 'sys.exit(0 if not [p for p in d[\"projects\"] if p[\"name\"]==\"ghost\"] and d[\"missing_in_disk\"] else 1)'"
check "archivos sin commitear contados (alpha=2: HANDOFF + untracked)" "q x 'sys.exit(0 if [p for p in d[\"projects\"] if p[\"name\"]==\"alpha\" and p[\"git\"][\"dirty\"]==2] else 1)'"
check "links: GitHub, sitio y Drive desde projects.toml" "grep -q 'href=\"https://github.com/zz-tester/alpha\"' '$H' && grep -q 'href=\"https://alpha.example.invalid\"' '$H' && grep -q 'Drive: remote:demo' '$H'"
check "tokens y costo de 30 días de la sesión de alpha" "q x 'sys.exit(0 if [p for p in d[\"projects\"] if p[\"name\"]==\"alpha\" and p[\"tokens_30d\"][\"input\"]==1000 and p[\"tokens_30d\"][\"cost_usd\"]==1.5] else 1)'"
check "proyecto sin tokens no muestra columna" "q x 'sys.exit(0 if [p for p in d[\"projects\"] if p[\"name\"]==\"beta\" and p[\"tokens_30d\"] is None] else 1)'"

# status thresholds (now = 2026-10-15)
st() { q x "print([p['status'] for p in d['projects'] if p['name']=='$1'][0])" | tr -d '\r'; }
[ "$(st alpha)" = activo ]     && ok "alpha (5 d) = activo"            || bad "alpha (5 d) = activo" "$(st alpha)"
[ "$(st d14)" = activo ]       && ok "14 días = activo"                || bad "14 días = activo" "$(st d14)"
[ "$(st d15)" = parado ]       && ok "15 días = parado"                || bad "15 días = parado" "$(st d15)"
[ "$(st d90)" = parado ]       && ok "90 días = parado"                || bad "90 días = parado" "$(st d90)"
[ "$(st d91)" = archivado ]    && ok "91 días = archivado"             || bad "91 días = archivado" "$(st d91)"
[ "$(st plain)" = activo ]     && ok "sin git: actividad desde sessions.json (14 d) = activo" || bad "plain" "$(st plain)"

# privacy
check "json sin texto de prompts por defecto" "! grep -q 'prompt secreto' '$J' && ! grep -q 'otro prompt' '$J'"
check "html muestra el último prompt (escapado y truncado)" "grep -q 'prompt secreto del hilo alpha' '$H'"
B --out "$T/out2" --include-prompts >/dev/null 2>&1
check "--include-prompts mete el texto en el json" "grep -q 'prompt secreto' '$T/out2/bitacora.json'"
n=$(grep -c "sk-\|password\|token=" "$J"); [ "$n" = 0 ] && ok "grep sk-|password|token= en el json = 0" || bad "grep secretos en json" "$n líneas"

# no network refs
bad_urls=$(grep -o 'https\?://[^"<> ]*' "$H" | grep -v '^https://github.com/zz-tester/alpha$' | grep -v '^https://alpha.example.invalid$' || true)
[ -z "$bad_urls" ] && ok "html sin http(s) salvo los links de GitHub y sitio" || bad "html sin http(s) extra" "$bad_urls"
check "html sin script externo ni <link>" "! grep -q '<script src\|<link ' '$H'"

# determinism
B --out "$T/o1" >/dev/null 2>&1; B --out "$T/o2" >/dev/null 2>&1
strip() { grep -v 'data-generated\|"generated"' "$1"; }
if diff <(strip "$T/o1/bitacora.html") <(strip "$T/o2/bitacora.html") >/dev/null && diff <(strip "$T/o1/bitacora.json") <(strip "$T/o2/bitacora.json") >/dev/null; then
  ok "dos corridas: mismo html y json salvo el timestamp"
else bad "dos corridas idénticas" "difieren"; fi

# degradation: no sessions.json, no history, missing projects.toml
mkdir -p "$T/empty"
if "$PY" bitacora.py --root "$R" --projects "$T/none.toml" --claude-dir "$T/empty" --archive "$T/empty" \
     --visor-dir "$V" --now "$NOW" --out "$T/o3" >/dev/null 2>&1 && ! grep -q 'in+out' "$T/o3/bitacora.html"; then
  ok "sin sessions.json/history/toml: genera igual y sin columna de tokens"
else bad "degradación sin fuentes" "falló o mostró tokens"; fi
check "visor ausente: texto 'no instalado'" "grep -q 'visor de enjambre: no instalado' '$H'"

echo
if [ "$fail" -eq 0 ]; then echo "$pass OK, 0 fallas."; exit 0; fi
echo "$pass OK, $fail fallas."; exit 1
