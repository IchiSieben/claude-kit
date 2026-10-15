#!/usr/bin/env bash
# tests/route_test.sh — /route resolves lanes from data, never from memory.
# Five task types go through the same two jq reads the skill does (routing.json lane ->
# family + effort, models.json family -> the one "current" id). The result must match
# tests/expected/route-cases.txt. The private repo and the public kit ship the same expected
# file, so this suite passing in both is the proof that both /route answer the same.
# Usage: bash tests/route_test.sh            (BLESS=1 rewrites the expected file)
set -uo pipefail
cd "$(dirname "$0")/.."
R=home/.claude/rules
EXP=tests/expected/route-cases.txt
ok=0; bad=0
pass() { ok=$((ok+1)); }
fail() { bad=$((bad+1)); printf '  FALLA %s\n' "$1"; }

for f in "$R/models.json" "$R/routing.json"; do
  jq -e . "$f" >/dev/null 2>&1 && pass || fail "$f no parsea"
done

# Every lane's family resolves to exactly one current model.
while IFS=$'\t' read -r lane fam; do
  n=$(jq --arg f "$fam" '[.models[] | select(.current and .family == $f)] | length' "$R/models.json")
  [ "$n" = 1 ] && pass || fail "lane $lane: familia $fam tiene $n modelos current"
done < <(jq -r '.lanes | to_entries[] | [.key, .value.model] | @tsv' "$R/routing.json" | tr -d '\r')

# The skill reads both files and names no model id of its own.
S=home/.claude/skills/route/SKILL.md
grep -q 'rules/models.json' "$S" && grep -q 'rules/routing.json' "$S" && pass || fail "SKILL.md no lee los dos archivos"
grep -qE 'claude-(opus|sonnet|haiku|fable)-[0-9]' "$S" && fail "SKILL.md escribe un id de modelo" || pass

# The five cases: task type -> lane, as written in the skill's routing rules.
resolve() {  # $1 type  $2 lane
  local fam eff id deff
  fam=$(jq -r --arg l "$2" '.lanes[$l].model' "$R/routing.json")
  eff=$(jq -r --arg l "$2" '.lanes[$l].effort // "-"' "$R/routing.json")
  id=$(jq -r --arg f "$fam" '.models[] | select(.current and .family == $f) | .id' "$R/models.json")
  deff=$(jq -r --arg f "$fam" '.models[] | select(.current and .family == $f) | .default_effort // "-"' "$R/models.json")
  [ "$eff" = "-" ] && eff="default($deff)"
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$id" "$eff"
}
got=$( resolve trivial  mecanico
       resolve prose    redactor
       resolve research investigador
       resolve debug    profundo
       resolve review   reviewer )
got=${got//$'\r'/}   # jq on Windows ends lines with CRLF

if [ "${BLESS:-0}" = 1 ]; then printf '%s\n' "$got" > "$EXP"; echo "blessed $EXP"; fi
if [ "$got" = "$(cat "$EXP" 2>/dev/null)" ]; then pass
else fail "los 5 casos difieren de $EXP"; diff <(printf '%s\n' "$got") "$EXP" | sed 's/^/    /'; fi

if [ "$bad" = 0 ]; then printf '\033[32m%d OK, 0 fallas.\033[0m\n' "$ok"; exit 0
else printf '\033[31m%d OK, %d fallas.\033[0m\n' "$ok" "$bad"; exit 1; fi
