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
  `ENJAMBRE_GUARD_HOSTS`, sin `mac`/`mac6` ni rutas fijas) y `rules/kit-enjambre.md`. Por qué:
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
