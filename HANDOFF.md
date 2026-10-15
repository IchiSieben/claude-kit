# HANDOFF — claude-kit · sesión V1 ecosistema (2026-10-15)

Prompt: `../docs/PROMPT-ecosistema-claude-code.md` §3 (V1). Modo dormido: sin preguntas en chat.

## Lo entendido y el plan (10 líneas)

1. El público es un espejo filtrado de un repo privado de origen; `~/.claude/statusline.sh` es byte a byte el del repo privado, no el del público.
2. `build-kit.sh` funciona, pero el repo privado avanzó desde el último export (locale C, HANDOFF con hora, segmento `enj`, umbrales visor-*, /route con models.json).
3. Por eso: el CÓDIGO (barra, umbrales, tests, hooks) se edita en el repo privado y se exporta; los DOCS (README, docs/, lección, ficha) se editan en el público.
4. Commit 0: export de sincronía, devolviendo `skills/route/SKILL.md` a la versión pública (lee `rules/models.json`, que no está en la allowlist).
5. Ítem 1: re-captura del payload 2.1.300 → estado de caché `⚡ caliente · Nm` / `⚠ enfriando · Nm` / `❄ fría`, `hit N%` aparte, umbral `cache-cooling` en thresholds.json, fixtures y GIF.
6. Push a main temprano (pre-aprobado con verify.sh verde) para que la Mac clone el árbol real.
7. Ítem 4: `AGENTS.md` con `tests-cmd` + `TASK-kit-media.md`, lanzado a la Mac por enjambre.
8. Ítem 3: módulo `home/.claude/modules/enjambre/` (hook guard + párrafo + README), `sync-to-home.sh --with enjambre`; PUBLISH.md/build-kit dejan de vetarlo.
9. Ítem 2: lección `docs/leccion-01-lee-tu-barra.{md,en.md}` + SVG de sectores + frontmatter `lesson:` en docs bilingües.
10. Ítem 5: `docs/FICHA-LANDING.md`, arquitectura con flujo "módulo enjambre", `FICHA-READY: <commit>`. Cierre con DECISIONES y NOTES.

## Estado

- **Sync (commit 0)** hecho: export del repo privado (locale C, HANDOFF con hora, segmento `enj`,
  bandas visor-*, /handoff y /spec), `/route` retenido (ver DECISIONES).
- **Ítem 1 hecho**: payload re-capturado (2.1.292–2.1.300, 24 renders, forma sin cambios); segmento
  de caché `⚡ caliente · 42m` / `⚡ enfriando · 4m` / `❄ fría · próximo turno reescribe` en la
  línea 1, `hit N%` en la línea 2 solo bajo `cache-hit-ok`; `cache-cooling` + `labels` en
  thresholds.json; 3 fixtures nuevas; goldens re-bendecidos. GIF/PNGs → trabajo de la Mac.
  Render budget: medido con la máquina cargada, sin cambio atribuible (DECISIONES).
- **Ítem 4 preparado**: `AGENTS.md` (`tests-cmd: bash tools/lane.sh`), `docs/tapes/media.sh`
  (VHS + ffmpeg + freeze), `TASK-kit-media.md`.
- **Ítem 4 BLOQUEADO (lanzado dos veces)**: `enjambre.py run ... --detach` responde
  "supervisor not confirmed in 10 s" y `collect kit-media` da `state unknown, beats 0`: el
  trabajo nunca arrancó en la Mac, mientras los trabajos del Landing en la misma Mac terminan
  `ok`. Hipótesis: la Mac no tiene clon de `claude-kit` y el supervisor muere antes del primer
  latido (mismo síntoma que `cert-media`). Para probarla lancé `clone-claude-kit` desde
  `enjambre-sandbox` (el remedio que pre-autoriza el prompt): ese supervisor sí arrancó y el
  trabajo terminó `ok`, pero el agente informó rc 127, `tools/clone-repos.sh: No such file or
  directory`. El script está en `origin/main` (`ea9bb40`), así que el worktree del nodo salió de
  una copia vieja del sandbox. No seguí: arreglar el sandbox del nodo no es de este repo. Sin
  video ni GIF nuevos; el README avisa que el GIF es anterior al rediseño.
  Para relanzar: `python ../enjambre/enjambre.py run --repo claude-kit --task TASK-kit-media.md
  --node mac --detach --budget 2 --model sonnet`, después `status --follow kit-media`.
- **Ítem 3 hecho**: `home/.claude/modules/enjambre/` (guardia de ssh PreToolUse + regla + README),
  `sync-to-home.sh --with enjambre`, 23 pruebas en verify.sh, secciones del README EN/ES.
- **Ítem 2 hecho**: `docs/leccion-01-lee-tu-barra.{md,en.md}`, SVG de sectores ES/EN
  (`docs/tapes/statusline-sectores.py`), frontmatter `lesson:` en 7 docs bilingües.
- **Ítem 5 hecho**: `docs/FICHA-LANDING.md` (live · usable · 128 tests · results con fecha;
  `media` aparte hasta que existan los archivos), flujo "módulo enjambre" en la arquitectura,
  `import-arquitecturas.py --check` → `check ok: 12 containers, 18 calls, 5 flows, 0 hits`.

FICHA-READY: be62c5c

- `verify.sh` rc=0 (128 pruebas; la deriva contra `~/.claude` es la esperada). `origin/main` = el commit que trae esta línea (fast-forward desde la rama `ecosistema/2026-10-15`).
- `~/.claude` NO se re-sincronizó (4 barras vivas): cuando quieras la barra nueva, en el repo
  privado de origen corre `bash sync-to-home.sh`, y reinicia Claude Code.

## Preguntas para el owner (máximo 3)

1. **/route**: el `/route` del repo privado lee `rules/models.json` y `routing.json`, que no se
   publican, así que el público conserva su versión vieja. ¿Se agregan esos dos archivos a la
   allowlist de build-kit (y se publica la tabla de modelos) o se mantiene el /route público?
2. **Trabajo de la Mac**: el supervisor arranca para `enjambre-sandbox` pero no para
   `claude-kit` (ni para `cert-media`), y el clon del sandbox en la Mac está atrasado respecto de
   `origin/main`. ¿Actualizas ese clon (`git pull` en la Mac) y confirmas si existe
   `~/Documents/Portfolio/claude-kit`, para relanzar `kit-media`?
3. **Ficha**: dice "128 tests" en vez de los "79" del prompt (la cifra de hoy). ¿Vale así?
