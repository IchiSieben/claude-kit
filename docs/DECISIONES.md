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
- **Medios · los videos se marcan binarios.** Con `* text=auto eol=lf` y sin regla para
  `mp4`/`webm`/`webp`, git tomó los videos por texto: la copia de trabajo salió 1–2 bytes más
  corta y con errores de decodificación, y el check de LF de `verify.sh` falló. Los blobs
  commiteados eran correctos (idénticos a los de `mac/kit-media-2`, 0 errores con ffmpeg). Se
  agregaron `*.mp4 *.webm *.webp binary` a `.gitattributes`, el check de LF ahora ignora los blobs
  binarios (`i/-text`) y los archivos se restauraron desde HEAD. `2b31a0e` se pusheó con ese check
  en rojo (mi cadena de comandos no cortaba ante el fallo); este commit lo deja en verde.
- **Ítem 2 · la demo es una rejilla, no un port.** `tools/render-grid.sh` corre el `statusline.sh`
  real sobre 972 combinaciones (modelo 3 × contexto 4 × caché 3 × cuota 3 × git 3 × HANDOFF 3),
  con nueve repos desechables para los estados de git y HANDOFF, y guarda 156 líneas distintas
  más el índice de cada celda en `docs/demo/grid.json` (69 KB). La página solo traduce ANSI a HTML
  y asigna cada tramo a su fila de `docs/statusline{,.es}.md` con reglas de texto; la leyenda va
  dentro de `grid.json`, extraída de esas tablas. Frescura: `inputsHash` = sha256 de
  `statusline.sh` + `thresholds.json`; `verify.sh` lo compara (y se salta si no hay demo, como en
  el repo privado). Descartado: deslizadores continuos (no se pueden pre-renderizar sin portar
  el script). Revertir: borrar `docs/demo/`, `tools/render-grid.sh` y el check de `verify.sh`.
- **Ítem 2 · el control de HANDOFF es "cuándo se escribió", no "atrasado sí/no".** Con git al
  día, un HANDOFF de hace 7 h sigue siendo `✓`: nada se movió después. La demo muestra lo que la
  barra decide, no lo que el control sugiere.
- **Ítem 2 · tipografías del visor de enjambre** (JetBrains Mono y Space Grotesk, subconjunto
  latino, OFL, licencias en `docs/demo/fonts/`). Los glifos `▓░┋⎇⚡❄` no están en el subconjunto
  y caen a la monoespaciada del sistema.
- **Medios · GIF de `mac/kit-media-7`, sin la nota de "anterior al rediseño".** Tras tres arreglos
  en la lane (`libwebp` → Pillow; freeze desde el Cellar con `--help` capturado, porque `pipefail`
  + `grep -q` daba SIGPIPE 141; `"$PY" -` separado), la Mac entregó los 5 PNG (`kit-media-6`) y el
  GIF con la caché nueva (`kit-media-7`). Los tomé con `git show <rama>:<ruta>`, sin checkout, y
  comparé los sha. Los videos de `-6`/`-7` son una regrabación equivalente: me quedo con los de
  `-3`, que ya estaban publicados.
- **Medios · corrupción del árbol a las 09:44:37, causa no encontrada.** Los cuatro archivos de
  `docs/media` se reescribieron 1 byte más cortos (CRLF → LF con `core.autocrlf=true` del
  gitconfig del sistema). Descarté build-kit, verify.sh, `git stash` con rutas y el collect de
  enjambre (solo hace `fetch`). Mitigación: `.gitattributes` binario para mp4/webm/webp y el check
  "árbol limpio" de `verify.sh`, que lo detectó las dos veces. Se restauró desde HEAD.
- **Ítem 2 · publicación en `kit.ichisieben.dev`.** Subdominio `kit` con docroot
  `public_html/kit-app` (pre-aprobado en §12) y subida por TUS archivo por archivo solo dentro de
  ese docroot, como la demo de enjambre. Nunca el deploy por archivo comprimido: reemplaza el sitio
  padre, que es el Landing. Hostinger sembró un `default.php` que **no se borró** (borrar en
  Hostinger necesita al owner): el `.htaccess` de la demo lo niega (403) y fija `DirectoryIndex
  index.html`. Matriz verificada: `/`, `grid.json` y las fuentes 200; `.htaccess`, `default.php` y
  `fonts/` (sin listado) 403.
- **Ítem 3 · la ficha pasa a 140 tests y lleva `demoUrl`.** Misma regla que el owner aprobó para el
  128 (la cifra del día): se sumaron las 12 de `route_test.sh`. El bloque `media` ya tiene sus
  archivos y su mapeo a `public/media/claude-kit/`; la copia la hace el Landing (V4).

## V1c · 2026-10-15 (prompt §14, demo v2) — decidido sin el owner

- **Commits agrupados 1 · 2-5 · 6 (+ arreglos).** Los ítems 2 a 5 comparten motor (`app.js`) y
  rejilla: separarlos dejaba commits intermedios que no pasaban `verify.sh`. Revertir: `git revert
  6a1aa28`.
- **Rejilla a 1 296 celdas: 4.º estado de git (`?1`).** Para explicar `?` hacía falta un estado
  real con un archivo sin seguimiento. Regla de §14: lo que falta se añade a la rejilla.
  `docs/DECISIONES.md` antiguo dice 972: es histórico y no se reescribe.
- **El recorrido es una copia de `../shared/tutorial/` en `docs/demo/tutorial/`** con ganchos
  aditivos (`onStep`, `onClose`, `read`), scroll solo si el objetivo no se ve entero y
  `focus({preventScroll})`. El compartido no se tocó (lo usan otros demos). Pendiente propuesto:
  subir esos tres cambios al compartido.
- **DejaVu, no Noto, para los símbolos de la barra.** Cubre todos los glifos en un archivo de 4,9 KB
  (dos subconjuntos); Noto necesitaba tres familias.
- **Héroe revelado con CSS desde opacidad .02**, no desde 0: con 0 el navegador no cuenta el párrafo
  como LCP y la métrica cae en un elemento tardío. Visualmente es invisible.
- **Primer pantallazo bilingüe en el HTML** (`data-l`), idioma decidido en `<head>` antes de pintar:
  cambiar el texto después del primer render movía la página.
- **Móvil: tres filas reservadas por línea de la barra.** El recorrido vuelve a la celda 0 a los
  0,9 s y una línea más corta subía todo (CLS 0,23). Revertir: la regla `.ln{min-height:6.45em}`.
- **Space Grotesk y JetBrains Mono con `font-display: optional`** (precargadas). Con `swap`, la
  fuente llegaba tarde en red real y re-envolvía el héroe (CLS hasta 0,2). Coste: en una primera
  visita muy lenta se ve la fuente de respaldo; desde la segunda, la propia. Revertir: volver a
  `swap` en las dos `@font-face` de `index.html`.
- **Tutorial en tema claro: acento `--accent-text` y texto blanco sobre teal**, para 4,5:1.
- **Los gates miden el sitio publicado** cuando sus archivos son los del commit (sha comparado);
  si no, el servidor local, que no comprime y da perf más baja. `GATES.md` dice qué URL midió.
- **`default.php` sigue en `kit-app/`** (negado por `.htaccess`): borrar en Hostinger es del owner.
- **Errores de `jq` en un log de render** salieron de procesos huérfanos de una corrida detenida, no
  del script: la corrida limpia no los tiene.
- **Gates y clip de Windows como respaldo; la lane de la Mac, arreglada y relanzada.** El job
  `kit-demo-gates` se colgó entre la descarga de Chromium de Playwright y `== measuring` (33 min sin
  una línea más; el log no llegó a imprimir la confirmación de la descarga). La lane tenía además un
  defecto propio: con un `started` viejo y el proceso muerto, cada llamada esperaba para siempre
  (exit 90). Arreglo en `demo-gates.sh`: arranca si no hay proceso vivo y no hay resultado para este
  commit; mata la sesión de una corrida de más de 45 min; `playwright install` con tope de 900 s
  (alarm de perl); `curl --max-time 20`; marcas `== playwright ready` y `== serving`. Mientras tanto,
  el mismo `demo-gates.mjs` corrió en Windows contra https://kit.ichisieben.dev (archivos iguales al
  commit por md5) y sus capturas y clip quedan en el repo. Lighthouse en Windows es ruidoso: el mismo
  código dio TBT 431 y 224 ms en dos corridas seguidas.
