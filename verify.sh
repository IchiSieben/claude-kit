#!/usr/bin/env bash
# Verifica lo que el HANDOFF da por HECHO. Se corre ENTERO antes de trabajo
# nuevo, al empezar cada sesion. Sale 0 solo si todo pasa.
#
# La regla que justifica este archivo: un HANDOFF que afirma algo falso es
# peor que no tenerlo, porque se planifica sobre el. Ya paso una vez -decia
# que `agy` no estaba instalado cuando llevaba tres semanas instalado- y
# costo dos pasos de plan que sobraban.
set -uo pipefail
cd "$(dirname "$0")"
fallos=0
ok()   { printf '  OK    %s\n' "$1"; }
falla(){ printf '  FALLA %s\n' "$1"; fallos=$((fallos+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else falla "$1"; fi; }

# python3 first (macOS has no `python`), but chosen by RUNNING it, not by `command -v`:
# on Windows `python3` resolves to the Microsoft Store stub, which exists and exits 49.
PY=""
for c in python3 python; do
  if "$c" -c 'import sys' >/dev/null 2>&1; then PY=$c; break; fi
done

echo "Fase A - statusline"
check "statusline.sh es bash valido y es la version de tokens absolutos" \
      'bash -n home/.claude/statusline.sh && grep -q CLAUDE_CODE_AUTO_COMPACT_WINDOW home/.claude/statusline.sh'
check "settings.json apunta a esa statusline" \
      'grep -q "statusline.sh" home/.claude/settings.json'

echo "Fase A - manual y hooks"
check "MANUAL.md tiene los 7 capitulos numerados" \
      '[ "$(grep -cE "^## [1-7]\. " home/.claude/MANUAL.md)" = 7 ]'
check "toda regla del manual cita su fuente (>=1 linea Fuente: por capitulo)" \
      '[ "$(grep -c "^\*Fuente:\|Fuente: " home/.claude/MANUAL.md)" -ge 7 ]'
check "la skill /manual existe y apunta al archivo espejado" \
      'test -f home/.claude/skills/manual/SKILL.md && grep -q "HOME/.claude/MANUAL.md" home/.claude/skills/manual/SKILL.md'
check "MANUAL.md viaja en el espejo" 'grep -q "MANUAL.md" mirror-lib.sh'
check "los 3 hooks nuevos son bash valido" \
      'bash -n home/.claude/hooks/precompact-draft.sh && bash -n home/.claude/hooks/session-drift-warn.sh && bash -n home/.claude/hooks/log-tool-failure.sh'
check "settings.json registra los 3 hooks" \
      'grep -q precompact-draft.sh home/.claude/settings.json && grep -q session-drift-warn.sh home/.claude/settings.json && grep -q log-tool-failure.sh home/.claude/settings.json'
check "los drafts automaticos NO son commiteables" \
      'git check-ignore -q "docs/handoffs/$(date +%Y-%m-%d)-draft.md"'
check "statusline.sh --drift responde (es la UNICA definicion de deriva)" \
      'bash home/.claude/statusline.sh --drift . | grep -qE "^(ok|stale|none) "'
check "suite de la statusline en verde" 'bash tests/statusline_test.sh'
check "suite de los hooks en verde"     'bash tests/hooks_test.sh'
check "suite del modulo enjambre en verde" 'bash tests/enjambre_module_test.sh'
check "suite de /route en verde"           'bash tests/route_test.sh'

echo "Fase A - umbrales (rules/thresholds.json es la unica fuente)"
check "thresholds.json es JSON valido, no vacio y sin ids repetidos" \
      'jq -e "(.thresholds|length)>0 and ([.thresholds[].id]|length) == ([.thresholds[].id]|unique|length)" home/.claude/rules/thresholds.json'
check "cada umbral trae condicion, prioridad y fuente" \
      '[ "$(jq -r "[.thresholds[] | select((.condition.value|type)!=\"number\" or (.priority|type)!=\"number\" or (.source|type)!=\"string\")] | length" home/.claude/rules/thresholds.json)" = 0 ]'
check "thresholds.json viaja en el espejo" 'grep -q "rules/\*.json" mirror-lib.sh'
# El espejo lo copia, pero .gitignore es una allowlist: si el archivo no esta permitido
# ahi, viaja a ~/.claude y NUNCA llega al repo de la otra maquina.
check "thresholds.json esta versionado (la allowlist de .gitignore lo permite)" \
      'git ls-files --error-unmatch home/.claude/rules/thresholds.json'
check "la barra no lleva ningun umbral por defecto en el codigo" \
      '! grep -qE "CC_CTX_(GREEN|RED)_K:-[0-9]" home/.claude/statusline.sh'
check "el hook de deriva lee el umbral del JSON, no del codigo" \
      'grep -q "rules/thresholds.json" home/.claude/hooks/session-drift-warn.sh && ! grep -qE "\(\( *[fs] *[<>]" home/.claude/hooks/session-drift-warn.sh'
check "la skill /ahora existe y usa el evaluador de la barra" \
      'test -f home/.claude/skills/ahora/SKILL.md && grep -q -- "--ahora" home/.claude/skills/ahora/SKILL.md'
check "statusline.sh --ahora responde exactamente 3 lineas" \
      '(( $(bash home/.claude/statusline.sh --ahora sesion-que-no-existe | wc -l) == 3 ))'

echo "Fase B - repo"
check "el arbol esta limpio (nada a medias de la sesion anterior)" \
      'git diff --quiet && git diff --cached --quiet'
check "todo lo versionado esta en LF en indice y arbol (salvo .ps1/.cmd/.bat e imagenes)" \
      '! git ls-files --eol | grep -v "i/-text" | grep -vE "\.(ps1|cmd|bat|png|gif)$" | grep -v "i/lf.*w/lf"'

echo "Fase E - espejo de ~/.claude en home/.claude"
check "mirror-lib.sh, sync-from-home.sh y sync-to-home.sh son bash valido" \
      'bash -n mirror-lib.sh && bash -n sync-from-home.sh && bash -n sync-to-home.sh'
check "nada sensible en el indice (credentials, history.jsonl, projects/, logs/)" \
      '! git ls-files | grep -E "credentials|history\.jsonl|(^|/)projects/|(^|/)logs/"'
# La deriva se INFORMA, no falla: decidir en que direccion va el sync es humano.
. ./mirror-lib.sh
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
deriva=0
while IFS= read -r rel; do
  if [ ! -f "home/.claude/$rel" ]; then
    printf '  DERIVA %s (en ~/.claude, no en el repo)\n' "$rel"; deriva=$((deriva+1))
  elif [ "$rel" = settings.json ]; then
    # Only the portable keys count: each machine legitimately has its own plugins, theme...
    same_portable "$CFG/$rel" "home/.claude/$rel" || { printf '  DERIVA %s (claves portables difieren)\n' "$rel"; deriva=$((deriva+1)); }
  elif ! same_lf "$CFG/$rel" "home/.claude/$rel"; then
    printf '  DERIVA %s (difiere)\n' "$rel"; deriva=$((deriva+1))
  fi
done < <(mirror_list "$CFG")
if [ -d home/.claude ]; then
  while IFS= read -r rel; do
    [ -f "$CFG/$rel" ] || { printf '  DERIVA %s (en el repo, no en ~/.claude)\n' "$rel"; deriva=$((deriva+1)); }
  done < <(mirror_list home/.claude)
fi
if [ "$deriva" -eq 0 ]; then ok "sin deriva entre ~/.claude y home/.claude"
else printf '  AVISO %s archivo(s) con deriva: sync-from-home.sh o sync-to-home.sh, segun donde este la verdad\n' "$deriva"; fi

echo
if [ "$fallos" -eq 0 ]; then
  echo "TODO OK - el HANDOFF dice la verdad; se puede trabajar."
else
  echo "$fallos comprobacion(es) FALLAN - arreglar o corregir el HANDOFF ANTES de trabajo nuevo."
fi
exit "$fallos"
