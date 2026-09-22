#!/usr/bin/env bash
# Golden-file tests for home/.claude/statusline.sh.
#
# Run: bash tests/statusline_test.sh        (or: bash home/.claude/statusline.sh --selftest)
# Bless after an intentional change: BLESS=1 bash tests/statusline_test.sh
#
# What makes this deterministic, and why each pin is needed:
#   CC_NOW                           freezes "now" (cache TTL countdown, HANDOFF age)
#   CLAUDE_CODE_AUTO_COMPACT_WINDOW  the denominator of the bar
#   CC_CTX_*, CC_BAR_WIDTH           the colour bands and the bar geometry
#   fixtures point current_dir at a path that does not exist, so git and the HANDOFF
#   drift take their "no data" branch instead of reading this machine's real repo.
# The one case that DOES exercise drift builds its own throwaway git repo (see below).
set -uo pipefail
cd "$(dirname "$0")/.."

SL=home/.claude/statusline.sh
FX=tests/fixtures
EXP=tests/expected
mkdir -p "$EXP"

export CC_NOW=1800000000
export CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000
export CC_CTX_GREEN_K=150 CC_CTX_RED_K=300 CC_BAR_WIDTH=20
# Every render writes a snapshot for /ahora. Point it at a throwaway directory, or running
# the tests would drop fixture sessions into this machine's real ~/.claude/state.
SNAPDIR=$(mktemp -d) || SNAPDIR=""
export CC_STATE_DIR="$SNAPDIR"
trap '[ -n "$SNAPDIR" ] && rm -rf "$SNAPDIR"' EXIT

pass=0; fail=0
red=$'\033[31m'; grn=$'\033[32m'; rst=$'\033[0m'

check() {                     # check <name> <actual>
  local name=$1 actual=$2 golden="$EXP/$1.txt"
  if [ "${BLESS:-}" = 1 ]; then
    printf '%s\n' "$actual" > "$golden"
    printf '  BLESS %s\n' "$name"; pass=$(( pass + 1 )); return
  fi
  if [ ! -f "$golden" ]; then
    printf '%s  FALLA %s (no hay golden; corré BLESS=1)%s\n' "$red" "$name" "$rst"
    fail=$(( fail + 1 )); return
  fi
  if [ "$actual" = "$(cat "$golden")" ]; then
    printf '  OK    %s\n' "$name"; pass=$(( pass + 1 ))
  else
    printf '%s  FALLA %s%s\n' "$red" "$name" "$rst"
    diff <(cat -v "$golden") <(printf '%s\n' "$actual" | cat -v) | sed 's/^/        /'
    fail=$(( fail + 1 ))
  fi
}

assert() {                    # assert <name> <condition-description> <0|1>
  if [ "$3" = 0 ]; then printf '  OK    %s\n' "$1"; pass=$(( pass + 1 ))
  else printf '%s  FALLA %s — %s%s\n' "$red" "$1" "$2" "$rst"; fail=$(( fail + 1 )); fi
}

echo "Fixtures (salida exacta contra golden)"
for f in session-new session-long fields-missing unknown-shape; do
  out=$(bash "$SL" < "$FX/$f.json")
  check "$f" "$out"
done

echo
echo "Invariantes: un campo ausente nunca se imprime como 0 ni como booleano"
# The 2.1.275 regression printed the literal "❄true%/0". Both halves are now banned.
for f in fields-missing unknown-shape session-new; do
  out=$(bash "$SL" < "$FX/$f.json")
  case "$out" in
    *true*|*false*) assert "$f: sin booleanos crudos" "imprimió true/false" 1 ;;
    *)              assert "$f: sin booleanos crudos" "" 0 ;;
  esac
done
out=$(bash "$SL" < "$FX/fields-missing.json")
case "$out" in
  *"⚠"*) assert "fields-missing: marca ⚠ lo que falta" "" 0 ;;
  *)     assert "fields-missing: marca ⚠ lo que falta" "no hay ninguna ⚠" 1 ;;
esac
# A cost that really IS zero must print 0.00, not ⚠ — that is the distinction the bar exists for.
case "$out" in
  *'$0.00'*) assert "fields-missing: un cero real sigue siendo 0.00" "" 0 ;;
  *)         assert "fields-missing: un cero real sigue siendo 0.00" "se comió el cero" 1 ;;
esac
# A payload of pure nonsense must still render two lines and exit 0.
out=$(bash "$SL" < "$FX/unknown-shape.json"); rc=$?
assert "unknown-shape: exit 0" "exit $rc" "$(( rc == 0 ? 0 : 1 ))"
assert "unknown-shape: 2 líneas" "salieron $(printf '%s\n' "$out" | wc -l)" \
       "$(( $(printf '%s\n' "$out" | wc -l) == 2 ? 0 : 1 ))"
# Truncated / non-JSON input must fail loud, not silently render zeros.
out=$(printf 'no soy json' | bash "$SL")
case "$out" in
  *"⚠ JSON"*) assert "entrada no-JSON: ⚠ JSON en rojo" "" 0 ;;
  *)          assert "entrada no-JSON: ⚠ JSON en rojo" "salió: $out" 1 ;;
esac

echo
echo "Umbrales: rules/thresholds.json es la única fuente"
TH=home/.claude/rules/thresholds.json
if jq -e . "$TH" >/dev/null 2>&1; then assert "thresholds.json es JSON válido" "" 0
else assert "thresholds.json es JSON válido" "jq no lo parsea" 1; fi
# Every threshold must carry the five things the schema promises, or the file is not a
# contract. An id twice over is worse than a missing one: the loser wins silently.
bad=$(jq -r '[.thresholds[] | select((.id|type)!="string" or (.priority|type)!="number"
             or (.condition.metric|type)!="string" or (.condition.op|type)!="string"
             or (.condition.value|type)!="number" or (.source|type)!="string")] | length' "$TH" 2>/dev/null)
assert "cada umbral trae id, prioridad, condición y fuente" "faltan campos en $bad" \
       "$( [ "${bad:-1}" = 0 ] && echo 0 || echo 1 )"
dup=$(jq -r '[.thresholds[].id] | (length - (unique | length))' "$TH" 2>/dev/null)
assert "los ids son únicos" "hay $dup repetido(s)" "$( [ "${dup:-1}" = 0 ] && echo 0 || echo 1 )"

# The numbers must live ONLY in the JSON: a fallback default in the code is the duplicate
# this whole change exists to remove.
if grep -qE 'CC_CTX_(GREEN|RED)_K:-[0-9]' "$SL"; then
  assert "statusline.sh no lleva umbrales por defecto" "quedó un :-<número>" 1
else
  assert "statusline.sh no lleva umbrales por defecto" "" 0
fi

# A copy of the bar with its OWN rules/ directory: that is what makes the next two cases
# real instead of a mock — it is the same resolution the installed copy uses.
thtmp=$(mktemp -d) || thtmp=""
if [ -z "$thtmp" ]; then
  printf '  SKIP  no se pudo crear un directorio temporal\n'
else
  mkdir -p "$thtmp/rules"
  cp "$SL" "$thtmp/statusline.sh"
  # 1. Change ONE number in the file: the bar must change its advice, with no code edited.
  jq '(.thresholds[] | select(.id=="quota-5h") | .condition.value) = 0' "$TH" > "$thtmp/rules/thresholds.json"
  out=$(bash "$thtmp/statusline.sh" < "$FX/session-long.json")
  case "$out" in
    *"límite 5h"*) assert "bajar quota-5h en el JSON cambia el hint" "" 0 ;;
    *)             assert "bajar quota-5h en el JSON cambia el hint" "siguió: ${out#*$'\n'}" 1 ;;
  esac
  # 1b. The file is THERE but does not parse — a truncated sync, a half-written edit. This is
  #     worse than a missing file, because `[ -f ]` says yes: it must land on exactly the same
  #     "⚠ umbrales, no advice" path, not on a half-loaded table.
  printf '{"thresholds": [ {"id": "roto",\n' > "$thtmp/rules/thresholds.json"
  out=$(bash "$thtmp/statusline.sh" < "$FX/session-long.json"); rc=$?
  assert "thresholds.json corrupto: exit 0" "exit $rc" "$(( rc == 0 ? 0 : 1 ))"
  case "$out" in
    *"⚠ umbrales"*) assert "thresholds.json corrupto: lo dice" "" 0 ;;
    *)              assert "thresholds.json corrupto: lo dice" "salió: ${out#*$'\n'}" 1 ;;
  esac
  case "$out" in
    *"/handoff"*|*"límite 5h"*) assert "thresholds.json corrupto: ningún hint inventado" "dio consejo igual" 1 ;;
    *)                          assert "thresholds.json corrupto: ningún hint inventado" "" 0 ;;
  esac
  # Same for /ahora: it must name the file, not print three lines of numbers with no rule.
  out=$(CC_STATE_DIR="$SNAPDIR" bash "$thtmp/statusline.sh" --ahora 00000000-0000-0000-0000-000000000000)
  n=$(printf '%s\n' "$out" | wc -l)
  assert "thresholds.json corrupto: /ahora sigue dando 3 líneas" "salieron $n" "$(( n == 3 ? 0 : 1 ))"
  case "$out" in
    *"no puedo leer los umbrales"*) assert "thresholds.json corrupto: /ahora lo dice" "" 0 ;;
    *)                              assert "thresholds.json corrupto: /ahora lo dice" "salió: ${out%%$'\n'*}" 1 ;;
  esac

  # 2. No thresholds file: no bands, no hints, and it SAYS so. Never a hardcoded fallback.
  rm -f "$thtmp/rules/thresholds.json"
  out=$(bash "$thtmp/statusline.sh" < "$FX/session-long.json"); rc=$?
  assert "sin thresholds.json: exit 0" "exit $rc" "$(( rc == 0 ? 0 : 1 ))"
  case "$out" in
    *"⚠ umbrales"*) assert "sin thresholds.json: lo dice" "" 0 ;;
    *)              assert "sin thresholds.json: lo dice" "salió: ${out#*$'\n'}" 1 ;;
  esac
  case "$out" in
    *"/handoff"*|*"límite 5h"*) assert "sin thresholds.json: ningún hint inventado" "dio consejo igual" 1 ;;
    *)                          assert "sin thresholds.json: ningún hint inventado" "" 0 ;;
  esac
  rm -rf "$thtmp"
fi

echo
echo "/ahora: tres líneas, del snapshot que escribió la barra"
SID=00000000-0000-0000-0000-000000000000
bash "$SL" < "$FX/session-long.json" >/dev/null
n=$(bash "$SL" --ahora "$SID" | wc -l)
assert "responde exactamente 3 líneas" "salieron $n" "$(( n == 3 ? 0 : 1 ))"
out=$(bash "$SL" --ahora "$SID")
case "$out" in
  *"contexto 334k"*) assert "línea 1: los números que vio la barra" "" 0 ;;
  *)                 assert "línea 1: los números que vio la barra" "salió: ${out%%$'\n'*}" 1 ;;
esac
case "$out" in
  *"por qué: context-red (context_k >= 300)"*) assert "línea 3: cita el umbral y su condición" "" 0 ;;
  *) assert "línea 3: cita el umbral y su condición" "salió: ${out##*$'\n'}" 1 ;;
esac
# The advice must be the bar's advice, not a second opinion.
barra=$(bash "$SL" < "$FX/session-long.json" | tail -1)
accion=$(bash "$SL" --ahora "$SID" | sed -n '2s/^hacé: //p')
case "$barra" in
  *"$accion"*) assert "da el MISMO consejo que la barra" "" 0 ;;
  *)           assert "da el MISMO consejo que la barra" "barra≠ahora: «$accion»" 1 ;;
esac
# Sin argumento: una skill NO recibe $CLAUDE_SESSION_ID (medido), asi que --ahora elige el
# snapshot mas nuevo de ESTE directorio. Si esto se rompe, /ahora responde "no hay snapshot"
# con la barra andando, que es como se descubrio el bug.
jq -n --arg d "$(pwd -W 2>/dev/null || pwd)" --arg s "11111111-2222-3333-4444-555555555555"    '{ts:9999999999, session:$s, five_pct:95, week_pct:10, context_k:10, context_pct:1,
     limit_k:400, cache_pct:99, session_min:5, ahead:0, behind:0, modified:0, untracked:0,
     handoff:"ok", handoff_age:"1h", handoff_dirty:0, handoff_sessions:0, fresh:1,
     causes:"", branch:"master", dir:$d, cost_usd:0, hint_id:"quota-5h"}'    > "$CC_STATE_DIR/11111111-2222-3333-4444-555555555555.json"
out=$(bash "$SL" --ahora)
case "$out" in
  *"elegida por directorio"*) assert "sin argumento: encuentra la sesión por directorio" "" 0 ;;
  *) assert "sin argumento: encuentra la sesión por directorio" "salió: ${out%%$'\n'*}" 1 ;;
esac
case "$out" in
  *"límite 5h al 95%"*) assert "sin argumento: evalúa ESE snapshot" "" 0 ;;
  *)                    assert "sin argumento: evalúa ESE snapshot" "no dio el hint de 5h" 1 ;;
esac
rm -f "$CC_STATE_DIR/11111111-2222-3333-4444-555555555555.json"

n=$(bash "$SL" --ahora sesion-que-no-existe | wc -l)
assert "sin snapshot: sigue respondiendo 3 líneas" "salieron $n" "$(( n == 3 ? 0 : 1 ))"
case "$(bash "$SL" --ahora sesion-que-no-existe)" in
  *"no hay snapshot"*) assert "sin snapshot: lo dice, no inventa números" "" 0 ;;
  *)                   assert "sin snapshot: lo dice, no inventa números" "no lo dijo" 1 ;;
esac

echo
echo "Deriva del HANDOFF (repo temporal, ejercita ·Nf ·Nc ·Ns de verdad)"
tmp=$(mktemp -d) || tmp=""
# The fake HOME lives OUTSIDE the repo: an events.jsonl created inside it would show up
# as an untracked file newer than HANDOFF.md and poison the very counter under test.
repo="$tmp/repo"; fakehome="$tmp/home"
mkdir -p "$repo" "$fakehome/.claude/logs" 2>/dev/null
if [ -z "$tmp" ] || ! git -C "$repo" init -q 2>/dev/null; then
  printf '  SKIP  no se pudo crear un repo temporal\n'
else
  # These cases compare mtimes against real files, so they must run on the real clock,
  # not the frozen CC_NOW the golden fixtures use: a faked future "now" would put the
  # HANDOFF's mtime ahead of every file git creates and every counter would read 0.
  printf -v real_now '%(%s)T' -1
  hm=$(( real_now - 7200 ))                 # HANDOFF written 2h ago
  : > "$fakehome/.claude/logs/events.jsonl"    # present but empty -> ·0s, not ·?s
  (
    cd "$repo"
    git config user.email t@t; git config user.name t; git config commit.gpgsign false
    echo "# handoff" > HANDOFF.md
    git add -A && git commit -qm "handoff"
    touch -d "@$hm" HANDOFF.md
  ) >/dev/null 2>&1
  payload=$("${JQ:-jq}" --arg d "$repo" '.workspace.current_dir=$d | .cwd=$d' "$FX/session-long.json")
  drift() { printf '%s' "$payload" | CC_NOW="$real_now" HOME="$fakehome" bash "$SL"; }

  # 1. nothing changed after it -> ✓HANDOFF. (No commit is newer: the only commit IS
  #    the one that saved HANDOFF.md, which must not count as work done after it.)
  out=$(drift)
  case "$out" in
    *"✓HANDOFF"*) assert "limpio: ✓HANDOFF" "" 0 ;;
    *)            assert "limpio: ✓HANDOFF" "salió: ${out#*$'\n'}" 1 ;;
  esac

  # 2. a dirty file newer than it -> ·1f, and never "sin HANDOFF".
  echo "cambio" > "$repo/otro.txt"
  out=$(drift)
  case "$out" in
    *"sin HANDOFF"*) assert "sucio: no dice 'sin HANDOFF'" "dijo sin HANDOFF" 1 ;;
    *"·1f"*)         assert "sucio: cuenta ·1f" "" 0 ;;
    *)               assert "sucio: cuenta ·1f" "salió: ${out#*$'\n'}" 1 ;;
  esac

  # 3. a real commit after it -> ·1c.
  ( cd "$repo" && git add -A && git commit -qm "trabajo posterior" ) >/dev/null 2>&1
  out=$(drift)
  case "$out" in
    *"·1c"*) assert "commit posterior: cuenta ·1c" "" 0 ;;
    *)       assert "commit posterior: cuenta ·1c" "salió: ${out#*$'\n'}" 1 ;;
  esac

  rm -rf "$tmp"
fi

echo
echo "Snapshot: se arma con jq, no pegando texto en una plantilla"
# A refname may contain a double quote (git check-ref-format allows it; only the FILESYSTEM
# refuses it as a loose ref on Windows, which is why this uses packed-refs). With the old
# printf template that quote closed the JSON string and every later /ahora said "el snapshot
# existe pero no se deja leer" — on a bar that looked perfectly fine.
qtmp=$(mktemp -d) || qtmp=""
qrepo="$qtmp/repo"
if [ -z "$qtmp" ] || ! (mkdir -p "$qrepo" && git -C "$qrepo" init -q -b main) 2>/dev/null; then
  printf '  SKIP  no se pudo crear un repo temporal\n'
else
  # `\` is the one char git check-ref-format itself rejects, so the backslash path is
  # covered by .dir below (a Windows path), not by the branch name.
  QBRANCH='feat/"raro"'
  (
    cd "$qrepo"
    git config user.email t@t; git config user.name t; git config commit.gpgsign false
    echo "# handoff" > HANDOFF.md
    git add -A && git commit -qm handoff
    oid=$(git rev-parse HEAD)
    # packed-refs is a plain text file, so it can hold a name NTFS would reject.
    printf '# pack-refs with: peeled fully-peeled sorted \n%s refs/heads/%s\n' "$oid" "$QBRANCH" > .git/packed-refs
    rm -f .git/refs/heads/main
    printf 'ref: refs/heads/%s\n' "$QBRANCH" > .git/HEAD
  ) >/dev/null 2>&1
  got_branch=$(git -C "$qrepo" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$got_branch" != "$QBRANCH" ]; then
    printf '  SKIP  este git no acepta la rama de prueba (dio «%s»)\n' "$got_branch"
  else
    QSID=99999999-9999-9999-9999-999999999999
    qsnapdir=$(mktemp -d)
    "${JQ:-jq}" --arg d "$qrepo" --arg s "$QSID" \
      '.workspace.current_dir=$d | .cwd=$d | .session_id=$s' "$FX/session-long.json" \
      | CC_STATE_DIR="$qsnapdir" bash "$SL" >/dev/null
    qsnap="$qsnapdir/$QSID.json"
    if [ ! -f "$qsnap" ]; then
      assert "rama con comillas: la barra escribe el snapshot" "no se creó $qsnap" 1
    else
      assert "rama con comillas: la barra escribe el snapshot" "" 0
      "${JQ:-jq}" -e . "$qsnap" >/dev/null 2>&1
      assert "rama con comillas: el snapshot es JSON válido" "jq no lo parsea" "$?"
      seen=$("${JQ:-jq}" -r '.branch' "$qsnap" 2>/dev/null); seen=${seen%$'\r'}
      assert "rama con comillas: .branch vuelve tal cual" "guardó «$seen»" \
             "$( [ "$seen" = "$QBRANCH" ] && echo 0 || echo 1 )"
      # .dir is the payload's own path, which the bar prints in its native (Windows) form,
      # so compare the tail: what is under test is that jq carried it through unmangled.
      seend=$("${JQ:-jq}" -r '.dir' "$qsnap" 2>/dev/null); seend=${seend%$'\r'}
      seend=${seend//\\//}
      assert "rama con comillas: .dir sigue siendo una ruta entera" "guardó «$seend»" \
             "$( [ "${seend##*/}" = "repo" ] && echo 0 || echo 1 )"
      out=$(CC_STATE_DIR="$qsnapdir" bash "$SL" --ahora "$QSID")
      case "$out" in
        *"no se deja leer"*) assert "rama con comillas: /ahora lo lee" "dijo que no lo puede leer" 1 ;;
        *)                   assert "rama con comillas: /ahora lo lee" "" 0 ;;
      esac
    fi
    rm -rf "$qsnapdir"
  fi
  rm -rf "$qtmp"
fi

echo
if [ "$fail" -eq 0 ]; then
  printf '%s%d OK, 0 fallas.%s\n' "$grn" "$pass" "$rst"
else
  printf '%s%d OK, %d FALLA(S).%s\n' "$red" "$pass" "$fail" "$rst"
fi
exit "$fail"
