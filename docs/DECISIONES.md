# Decisiones tomadas sin el owner

Formato: fecha · tarea · qué se eligió · por qué · qué se descartó · cómo revertirlo.

## 2026-10-15 · V1 ecosistema

- **Dónde se edita el código.** Elegido: barra, umbrales, tests y hooks se editan en
  el repo privado de origen y se exportan con `tools/build-kit.sh`; documentación solo en el público.
  Por qué: `~/.claude/statusline.sh` es idéntico al del repo privado; un cambio solo en el
  público no llegaría a la barra real y el próximo export lo pisaría. Descartado: trabajar en
  el público directo (la salida del §3 es para un `build-kit.sh` roto, y no lo está).
  Revertir: no aplica; los commits del repo privado quedan en su rama principal.
- **`/route` no se exporta.** Elegido: tras cada export se devuelve
  `home/.claude/skills/route/SKILL.md` a la versión pública. Por qué: la del repo privado lee
  `~/.claude/rules/models.json` y `routing.json`, que no están en la allowlist de PUBLISH.md:
  el kit publicaría un skill con una referencia colgante. Descartado: añadir esos dos JSON a la
  allowlist (los genera `model-intel.py`, que tampoco se publica; quedarían viejos).
  Revertir / decidir: añadir `rules/models.json` + `rules/routing.json` (+ `tools/model-intel.py`)
  a `AS_IS` en `build-kit.sh` y dejar de restaurar el archivo. **Pregunta para el owner.**
- **Ítem 1 · símbolo de "enfriando".** Elegido: `⚡ enfriando · 4m` en ámbar, no el
  `⚠ enfriando` del prompt. Por qué: en esta barra `⚠` significa "dato faltante o ilegible"
  (la regla sobre la que está construida); usarlo para un estado real lo rompería. El símbolo
  dice el hecho (sigue caliente), el color y la palabra dicen la urgencia. Revertir: cambiar
  `cseg="⚡"` por `cseg="⚠"` en la rama `cooling` del segmento de caché de `statusline.sh`.
- **Ítem 1 · fría en cian.** `❄ fría · próximo turno reescribe` va en cian, no en rojo: una
  caché fría tras una pausa es normal, no un error. Revertir: `CYN` → `RED` en esa línea.
- **Ítem 1 · cuándo se muestra el hit.** `hit N%` solo por debajo de `cache-hit-ok` (85, el
  número cosmético que vivía en el código y ahora está en thresholds.json). Sin thresholds.json
  se muestra siempre. Revertir: subir `cache-hit-ok` a 101 lo muestra siempre.
- **Ítem 1 · `cache_left_min` vale -1 en una caché fría.** Así `cache-cooling` (cuenta atrás)
  no puede disparar sobre una caché ya expirada; "fría" lo dice el estado, no el número.
- **Ítem 1 · numeración del mapa.** Los sectores #10–#12 conservan su número aunque el estado
  de caché pasó a la línea 1; `statusline-map.png` no se re-numeró (es una captura de terminal
  real, no se regenera en Windows). El SVG nuevo del ítem 2 dibuja el orden actual.
- **Ítem 1 · GIF.** `docs/tapes/render-states.sh` necesita `freeze` (charmbracelet), que no
  está en esta máquina; descargar un binario de terceros de madrugada no estaba pre-aprobado.
  El regenerado va en el trabajo de la Mac (ítem 4). Revertir: correr el script donde haya
  `freeze`.
- **Ítem 1 · render budget.** Medido con la máquina cargada (4 sesiones vivas): 440–580 ms el
  piso y 790–930 ms el render completo, vieja y nueva versión dentro del mismo ruido. El
  cambio no añade forks (las palabras viajan en la misma llamada a jq). No se optimizó a
  ciegas: la mejora candidata (quitar el `jq` que escribe el snapshot de /ahora, ~60 ms) cambia
  una decisión de seguridad documentada (comillas en ramas). Queda para medir en frío.
- **Ítem 1 · `5h ⚠` en sesiones inactivas.** La captura 2.1.292 trae `rate_limits.seven_day`
  sin `five_hour`. La barra lo pinta como campo faltante (`5h ⚠`). Se dejó así (regla del
  repo); si molesta, tratar `five_hour` ausente como "sin dato" en blanco.
- **Ítem 3 · el módulo es una versión genérica, no el hook del owner.** Elegido:
  `modules/enjambre/` con `enjambre-ssh-guard.sh` (hosts desde el `nodes.toml` del usuario o
  `ENJAMBRE_GUARD_HOSTS`, sin nombres de nodos del owner ni rutas fijas) y `rules/kit-enjambre.md`. Por qué:
  PUBLISH.md vetaba el hook y la regla personales porque nombran máquinas y rutas del owner; el
  prompt pide que lo compartido viva en el kit. Los personales siguen sin publicarse; el escaneo
  de `build-kit.sh` ahora busca esos marcadores personales en vez de `ENJAMBRE_RAW_SSH`.
  Revertir: quitar la fila del módulo en PUBLISH.md y las líneas `modules/enjambre` del `AS_IS`.
- **Ítem 3 · el "párrafo del CLAUDE.md global" es un archivo de reglas.** Elegido:
  `~/.claude/rules/kit-enjambre.md` (se carga siempre, igual que CLAUDE.md). Por qué:
  `sync-to-home.sh` reescribe `CLAUDE.md` en cada sincronización y borraría un párrafo añadido.
  Revertir: mover el texto a `home/.claude/CLAUDE.md`.
- **Ítem 3 · un sync sin `--with` des-registra el hook.** La clave portable `hooks` del espejo
  reemplaza los arrays; el archivo del hook queda en disco, inerte. Documentado en el README del
  módulo ("pasa la bandera siempre"). Alternativa descartada: recordar los módulos instalados en
  un archivo de estado (contradice "sin la bandera no toca nada").
- **Ítem 3 · el 900 s del bloque `enj` pasó a thresholds.json** (`enjambre-stale`, 15 min).
- **Ítem 2 · orden de la ruta "Code Like Me".** 1 lección de la barra · 2 routing · 3 context ·
  4 handoff · 5 hooks · 6 thresholds · 7 reviewer · 8 manual-and-now. Niveles 0–2 (la barra es
  la entrada, nivel 0). Formato del frontmatter: el bloque YAML de las lecciones de enjambre.
  Revertir: editar los números en el frontmatter de cada `docs/*.md`.
- **Ítem 2 · el SVG se genera.** `docs/tapes/statusline-sectores.py` escribe la versión ES y EN
  con texto real y colores por variables CSS (claro/oscuro por `prefers-color-scheme` y por
  `data-theme`). El texto de la barra dentro del dibujo es el del estado "enfriando".
- **Ítem 5 · la ficha dice 128 tests, no 79.** El prompt pedía `"Open source · 79 tests"`; 79 era
  la cifra del 2026-09-22. Hoy: statusline 67 + hooks 38 + módulo enjambre 23 = 128, verificado
  corriendo las tres suites. Los badges de los dos README también pasan de 79 a 128. Revertir:
  reemplazar 128 por 79 en `docs/FICHA-LANDING.md` y los badges.
- **Ítem 5 · `media` va aparte en la ficha.** El esquema del Landing valida que los archivos
  existan en `public/media/claude-kit/`, y no existen hasta que vuelva el trabajo `kit-media` de
  la Mac. El bloque queda listo para pegar debajo del frontmatter; pegarlo antes rompe el build.
- **Ítem 5 · el flujo "módulo enjambre" no añade caja.** Reutiliza `sync`, `hk` y las aristas e4,
  e8 y e9; la caja de hooks lista el guardia como "Opcional". Contenedores y llamadas no cambian
  (12 y 18), los flujos pasan a 5. `import-arquitecturas.py --check <ruta>` → `check ok`.
- **Ítem 5 · incidente: el importador escribió en el worktree del Landing.** Corrí
  `import-arquitecturas.py` sin argumento (hace la importación completa, no el check) dentro de
  `wt/landing-ecosistema`. Escribió `public/arquitecturas/claude-kit/index.html` y
  `src/content/architectures/claude-kit.json` con este flujo nuevo. La ventana del Landing los
  commiteó en `aa469aa` antes de que yo los revirtiera; el contenido es el mismo de este commit,
  así que no hay nada que deshacer. No toqué ningún otro archivo de ese worktree.

## V1b · 2026-10-15 (respuestas del owner, prompt §12)

- **Ítem 1 · `models.json` y `routing.json` publicados.** Auditoría: `models.json` son datos de
  la documentación pública de Anthropic (ids, contexto, precios); `routing.json` no tiene secretos
  ni terceros. Se exporta `routing.json` con `decisions: []` (el log fechado es privado, como pidió
  el owner); también `tools/model-intel.py`, porque el SKILL lo nombra y sin él el kit diría una
  herramienta que no trae. El `/route` público es ahora byte a byte el del repo privado.
  Revertir: quitar las dos líneas del `AS_IS` y la línea `jq '.decisions = []'` de `build-kit.sh`.
- **Ítem 1 · la prueba "misma recomendación" es determinista.** `/route` es un skill (lo ejecuta un
  modelo), así que el test resuelve lo que el skill lee: tipo → carril → familia + esfuerzo →
  id `current`, para 5 casos, contra `tests/expected/route-cases.txt`. El archivo esperado es el
  mismo en los dos repos; la suite en verde en ambos es la prueba. Además: el SKILL no puede
  escribir un id de modelo, y cada familia de carril tiene exactamente un modelo `current`.
- **Ítem 1 · el draft de compactación salió del árbol.** `docs/handoffs/2026-10-15-draft.md`
  (ignorado por git, escrito por el hook al compactar) tenía rutas locales y el escaneo de
  `build-kit` recorre el disco, no solo lo versionado. Se movió al scratchpad de la sesión, no se
  borró.
- **Medios · video de `mac/kit-media-2`, póster local.** V2b clonó el repo en la Mac y la lane
  grabó el webm (112 KB) y el mp4 (86 KB), pero murió en el póster: el ffmpeg de Homebrew no trae
  `libwebp`. Tomé solo `docs/media/*` de la rama (no `result.json`). `media.sh` ahora extrae el
  fotograma 0 con ffmpeg y escribe el WebP con Pillow, y con ese mismo método generé aquí
  `statusline-poster.webp` (1280x720) y `statusline-poster-mobile.webp` (640x360). Los PNG de la
  leyenda y el GIF siguen pendientes de un `kit-media-3`, que lanza V2b.
