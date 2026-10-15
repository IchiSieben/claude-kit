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

## Preguntas de V1 — respondidas por el owner (prompt §12)

1. `/route`: sí, publicar `models.json` y `routing.json` → hecho (ítem 1 de V1b).
2. Clon y medios en la Mac: los hizo V2b → hecho (kit-media-3/6/7).
3. 128 tests: vale la cifra del día → hoy 140.

## V1b · 2026-10-15 (prompt §12)

- **Ítem 1 hecho** (`4677b24`): `rules/models.json`, `rules/routing.json` (con `decisions: []`) y
  `tools/model-intel.py` publicados; el `/route` público es byte a byte el del repo privado.
  `tests/route_test.sh` (12) resuelve 5 casos desde los datos contra un `expected` compartido por
  los dos repos. README y `docs/routing{,.es}.md` explican qué decide cada archivo y cómo editarlo.
- **Ítem 2 hecho** (`51b3812`, publicado en `2929d46`): **https://kit.ichisieben.dev/**. Es
  `docs/demo/index.html` sobre `docs/demo/grid.json`: 972 combinaciones renderizadas por el
  `statusline.sh` real (`tools/render-grid.sh`, ~5 min en Windows). Cada sector se puede tocar y
  abre su fila de la leyenda. Claro/oscuro, ES/EN, 390 px y teclado. `verify.sh` falla si cambia la
  barra y no se regenera la rejilla. La lección 01 y los README enlazan a la demo.
- **Ítem 3 hecho**: video de `mac/kit-media-3`, PNG de `-6`, GIF de `-7`; `FICHA-LANDING.md` con
  `demoUrl`, 140 tests y el bloque `media` con su mapeo. Aviso a V4 (`landing-d5`) enviado.
  V4 confirmó: ficha importada (medios sha256 idénticos, lección 01 re-importada) en el commit
  `1e01302` de la rama `v4b/a11y-nav` del Landing; pasa a main tras el último gate de la Mac.
- Arreglos de la lane `media` en el camino: póster con Pillow (sin `libwebp`), freeze desde el
  Cellar con `--help` capturado (SIGPIPE 141 con `pipefail`), `"$PY" -` separado. Videos marcados
  binarios en `.gitattributes`. Hubo una corrupción del árbol sin causa encontrada (DECISIONES).
- Hostinger: el docroot `kit-app` conserva el `default.php` sembrado por Hostinger (negado por
  `.htaccess`). Si quieres borrarlo, hazlo tú en hPanel; no hace falta.
- `origin/main` = el commit que trae esta sección. `~/.claude` sigue sin re-sincronizar: para la
  barra y el `/route` nuevos, en el repo privado de origen corre `bash sync-to-home.sh` y reinicia.

## V1c · 2026-10-15 (prompt §14, demo v2)

En vivo: **https://kit.ichisieben.dev/**. Los archivos publicados son iguales por md5 a `3bdb15c`
(`index.html`, `app.js`, `content.js`, `grid.json`, `tutorial/tutorial.js`). Rama
`demo-v2/2026-10-15`, que también está en `origin/main`.

- **Ítem 1** `7464d6b`: subconjuntos de DejaVu para los símbolos de la barra (4,9 KB, verificados
  glifo a glifo) + `KitMono-Regular.ttf` para freeze.
- **Ítems 2-5** `6a1aa28` (+ `61a8a3e`):
  - causa → efecto: línea con punto viajero, halo y rótulo que lee los umbrales de `grid.json`;
  - recorrido de 8 pasos que mueve los controles de verdad;
  - "Reproducir una sesión": 9 renders reales en 3 h;
  - 18 sectores + @node × 3 niveles, con mini-barra de estados reales y glosario ES/EN;
  - "Qué te llevas": árbol `~/.claude` y comandos.
  - Rejilla: 1 296 celdas.
- **Ítem 6** `244cace`, `9a12f53`, `bf0f94d`, `a8c5a94`, `3bdb15c`, `96e52d5`, `ea2f134`.
  Gates medidos **en Windows contra producción** (`evidence/demo-v2/GATES.md`):
  - a11y 100, CLS 0, axe 0 en 5 estados, parpadeo 0 cortes, 15 capturas;
  - JS de unos 31 KB gzip;
  - **perf: mediana 88, rango 80-95**, en una máquina ruidosa (el mismo código dio TBT 431 y 224 ms
    en dos corridas seguidas).
- **Ítem 7** `2449d5b` + `c0ee580`:
  - clip de la ficha re-grabado desde la demo nueva, con el póster en el fotograma de 5,6 s;
  - `docs/FICHA-LANDING.md` actualizado;
  - `docs/DISENO-DEMO.md` escrito;
  - aviso a V4 (`landing-d5`) con rutas y sha256.
- **Mac**:
  - `kit-demo-gates` se colgó después de descargar Chromium de Playwright.
  - La lane se arregló (`96e52d5`): reinicia una corrida muerta o colgada, pone tope a
    `playwright install` y a `curl`, y deja marcas de progreso.
  - `kit-demo-gates-2` y `-3` (`407636b`: salta la instalación si Chromium está completo en la
    caché) terminaron con **exit 21**. Playwright se niega a instalar mientras otro proceso tenga
    `~/Library/Caches/ms-playwright/__dirlock`, y el Chromium de la primera corrida quedó a medio
    extraer. **BLOQUEADO, lo hace el owner en la Mac:** matar el proceso colgado de la primera
    corrida (`pgrep -fl "playwright install"`), borrar `~/Library/Caches/ms-playwright/__dirlock`
    y `chromium-1140`, y relanzar:
    `python ../enjambre/enjambre.py run --repo claude-kit --task TASK-kit-demo-gates-3.md --node mac
    --detach --budget 2 --model sonnet` (la lane arranca sola de cero en un commit nuevo).
  - Mientras tanto valen los gates de Windows. Si la Mac entrega, sus resultados se traen con
    `git show mac/<job>:<ruta>`, nunca con checkout.
- **Pendiente, propuesto**:
  - El TBT restante es sobre todo estilo/layout. Lo más pesado es una tarea de ~450 ms cuando llega
    `grid.json`: el segundo `applyLang()` reconstruye controles, árbol, tarjetas y glosario de una
    vez.
  - Siguiente experimento: diferir la construcción de tarjetas y glosario como se hizo con
    `collectStates`. Medirlo contra una línea base de la Mac, no de Windows.
  - Subir a `../shared/tutorial` los tres cambios del recorrido: `onStep`/`onClose`/`read`, scroll
    solo si hace falta y `focus({preventScroll})`.
- Hostinger: `kit-app/default.php` sigue allí, negado por `.htaccess`. Borrarlo es decisión del
  owner.

## V1d · 2026-10-15 (prompt §19: lo que el kit dice de sí mismo)

- **Mac primero**: `kit-demo-gates-5` ok tras pasar la lane a Playwright 1.60.0. Perf mediana 99,
  a11y 100, axe 0, 0 cortes de parpadeo; el experimento de fuentes/JS no hacía falta. La evidencia
  se trajo con `git show`; los medios re-grabados no (el Landing tiene los publicados por sha256).
- **Ítem 1 (barra)**: de 8 a 6 procesos por render completo (de 10 a 7 con commits sin push; el piso,
  de 4 a 2). A/B intercalado en Windows, n=3 y máquina cargada: 911 → 782 ms el completo y
  437 → 321 ms el piso. La meta de 200 ms se corrigió: el piso de Windows es ~225 ms. Detalle y
  la hipótesis de caché rechazada: `docs/statusline-internals.md`. `GIT_OPTIONAL_LOCKS=0`.
  `tools/bench-statusline.sh`. Columna de la Mac: `TASK-kit-bench-1.md` (lane `bench`), lanzar con
  `python ../enjambre/enjambre.py run --repo claude-kit --task TASK-kit-bench-1.md --node mac
  --detach --budget 1 --model sonnet` y copiar las cifras a la tabla.
- **Ítem 2 (guardas)**: `.githooks/pre-push` en los dos repos (`bash tools/install-hooks.sh [repo]`
  para otros repos), `.gitattributes` con binarios explícitos y un lint de `set -euo pipefail`
  en verify. En uso real: el hook dejó pasar el push del orquestador con verify en verde, y la
  cadena `verify && push` frenó un push del kit con el árbol sucio. La negación por el hook en sí
  la prueba `tests/prepush_test.sh`.
- **Ítem 3 (partidas)**: `harvest.py` v2, `partidas.py`, `docs/harvest{,.es}.md`. Salidas en
  `~/claude-archive/partidas.{json,html,txt}`.
- **Ítem 4 (bitácora)**: `bitacora.py` → `~/claude-archive/bitacora.{html,json}`, 38 proyectos.
- **Arreglos de build-kit por el camino**: la auditoría estaba ciega bajo `pipefail` y `sed -i`
  recortaba un byte a los videos. Los dos tienen prueba (`tests/build_kit_test.sh`, solo en el
  privado).
- **Pendiente del owner**:
  - correr `bash sync-to-home.sh` en el repo privado al cerrar el día (hay sesiones vivas) y
    reiniciar Claude Code; `~/.claude/rules/thresholds.json` está viejo (le falta
    `cache-hit-ok`), y hasta entonces partidas usa la copia del repo;
  - en cada clon nuevo de los dos repos, `bash tools/install-hooks.sh` (`core.hooksPath` es
    configuración local);
  - re-importar `docs/FICHA-LANDING.md` en el Landing (242 tests, meta de render corregida).
- La rejilla de la demo regenerada no se subió a `kit-app`: solo cambian el hash y una hora.
