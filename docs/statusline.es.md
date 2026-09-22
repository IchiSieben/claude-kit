# Leyenda de la barra de estado

La barra renderiza dos líneas a partir del JSON que Claude Code envía por stdin al comando
en cada render (`home/.claude/statusline.sh`). Ningún número sale del script mismo:

> EVERY number this bar reacts to lives in rules/thresholds.json, next to this script.
> None of them is written here: a threshold that exists in two places drifts. If that
> file is missing or unreadable the bar says `⚠ umbrales` and stops colouring and
> hinting — a threshold you cannot read is not the same thing as a threshold that is
> not crossed.

> THE RULE THIS FILE IS BUILT AROUND: a missing or unparsable field prints ⚠ in amber,
> never 0 and never a raw boolean. "No data" and "the data is zero" must not look
> alike — that is the whole point of a status line you trust at a glance.

## La leyenda

Orden de impresión, línea 1 y luego línea 2. El `#` coincide con los números de
`docs/img/statusline-map.png`.

| # | Símbolo / ejemplo | Significado | Fuente | Umbral / color |
|---|---|---|---|---|
| 1 | `Sonnet 5` / `⚠ modelo` | Nombre visible del modelo | `.model.display_name` | ninguno — texto plano o `⚠` |
| 2 | `·high` | Nivel de esfuerzo, se omite si el campo es null o falta | `.effort.level` | ninguno |
| 3 | `▓░┋` (20 caracteres) | Barra de contexto, escala 0..techo de auto-compact. `┋` marca la banda `context-red` dentro de esa escala | `.context_window.current_usage.{input,cache_creation_input,cache_read_input}_tokens` (sumados), o como respaldo `.context_window.used_percentage × .context_window.context_window_size` | `context-red` (id, ≥300) rojo, `context-amber` (id, ≥150) ámbar, por debajo de ambos verde — el color solo aparece si `rules/thresholds.json` cargó (`TH_OK`) |
| 4 | `123k/400k ⚠` | Tokens usados / techo de auto-compact, en esa unidad. `⚠` final cuando lo usado ≥ `context-red` | tokens usados como en #3; techo desde `CLAUDE_CODE_AUTO_COMPACT_WINDOW` (acepta `400000`/`400k`/`1M`), si no ~97% de `.context_window.context_window_size` | id `context-red` para el `⚠` |
| 5 | `62% of 1M` | Tokens usados como % de la ventana completa, y el tamaño de esa ventana (`k` o `M`) | `.context_window.context_window_size` | ninguno |
| 6 | `$0.42` / `$⚠` | Estimado de costo — lee `.cost.total_cost_usd` tal cual y lo imprime con `%.2f`. Es una cifra que Claude Code calcula para la sesión, no una factura | `.cost.total_cost_usd` | ninguno |
| 7 | `59m` / `⚠m` | Tiempo transcurrido de sesión, `.cost.total_duration_ms / 60000` | `.cost.total_duration_ms` | ninguno |
| 8 | `5h 96%` | Cuota del plan de 5 horas consumida. En blanco (no `⚠`) cuando `.rate_limits` es `null` — eso es "todavía no se mide", un estado real | `.rate_limits.five_hour.used_percentage` | `quota-5h` (id, ≥90) dispara la sugerencia (#18); no tiene color propio de barra |
| 9 | `7d 40%` | Cuota del plan de 7 días consumida, misma regla null-vs-faltante que #8 | `.rate_limits.seven_day.used_percentage` | ninguno definido en thresholds.json |
| 10 | `⚡96%` / `❄96%` / `⚠96%` | Tasa de acierto de caché. Símbolo: `⚡` caliente, `❄` frío, `⚠` cuando `warm` no es ni true ni false. El segmento queda en blanco (no `⚠`) cuando `.prompt_cache` es `null` (antes de la primera llamada) | `.prompt_cache.hit_ratio` (×100, truncado), `.prompt_cache.warm` | 85 (verde cosmético, escrito en el script, no en thresholds.json) verde; `cache-cold` (id, <60) banda ámbar/roja; por debajo de `cache-cold` rojo |
| 11 | `/59m`, `/1h2m`, `/exp`, `/⚠` | Cuenta regresiva del TTL de caché. Se calcula desde `expires_at` cuando existe; si no, cae al string literal `ttl`; `⚠` solo cuando el propio `ttl` es el centinela no parseable | `.prompt_cache.expires_at` (preferido), si no `.prompt_cache.ttl` | ninguno |
| 12 | `(3 miss)` / `(⚠ miss)` | Cantidad de fallos de caché en este render, solo se muestra si es >0 o ilegible | `.prompt_cache.misses` | ninguno |
| 13 | `+931/-5` / `⚠ diff` | Líneas agregadas/eliminadas en la sesión, solo se muestra si alguna es >0 | `.cost.total_lines_added`, `.cost.total_lines_removed` | ninguno |
| 14 | `⎇ main ↑1 ↓0 ●3 ?1`, `⊘` | Rama, commits adelante/atrás del upstream, cantidad de modificados, cantidad de sin seguimiento. `⊘` reemplaza el par adelante/atrás cuando no hay upstream | `git -C <dir> status --porcelain=v2 --branch`, corrido sobre `.workspace.current_dir` | `unpushed` (id, ahead>0, param 7200s) pone `↑N` en ámbar cuando el commit más viejo sin push tiene ≥2h, y dispara la sugerencia (#18) |
| 15 | `✓HANDOFF` / `⚠HANDOFF 7h ·4f ·1c ·0s` / `⚠ sin HANDOFF` | Deriva de HANDOFF.md: horas desde su mtime, archivos sucios más nuevos que él, commits desde entonces (sin contar uno que solo toque HANDOFF.md), sesiones iniciadas desde entonces (de `~/.claude/logs/events.jsonl`) | `drift_scan()` en el script; el contador de sesiones necesita `HOME` y un log de eventos legible | rojo cuando dispara `handoff-drift-files` (id, >20f) o `handoff-drift-sessions` (id, ≥2s), si no ámbar; `✓` verde; "sin HANDOFF" ámbar |
| 16 | `⚠ umbrales` | `rules/thresholds.json` falta, no se puede leer, o falló al parsear en este render — bandas y sugerencias quedan apagadas | ausencia de `$TH_FILE` o falla de `th_load` | n/a — esta línea significa que los umbrales no se pudieron verificar en absoluto |
| 17 | `[nombre-sesion]` | Nombre de la sesión, se omite si falta | `.session_name` | ninguno |
| 18 | texto magenta, p. ej. `↑1 sin push → git push` | UNA sola sugerencia: el umbral de mayor prioridad que dispara ahora mismo, redactado desde `actions.default`/`actions.fresh`/`actions.nodata` de thresholds.json | `th_pick()` recorre los umbrales ordenados por `priority` (ascendente, el número menor dispara primero): `quota-5h` → `context-red` → `cache-cold` → `session-long` (con puerta: también debe disparar `context-amber`) → `unpushed` | el color siempre es magenta; cuál umbral gana depende solo del orden de prioridad en `rules/thresholds.json`, nunca de un número en este script |

### Estados de línea completa (anteceden a todo lo anterior)

| Símbolo | Significado | Fuente |
|---|---|---|
| `⚠ jq` (rojo) | No se encontró el binario `jq` en `PATH` ni en el shim de WinGet | arranque del script, antes de leer cualquier payload |
| `⚠ JSON` (rojo) | La única llamada a `jq` sobre stdin no produjo nada — payload de forma desconocida | primera llamada a jq de la función de render |
| `⚠ contexto` (ámbar) | El uso de tokens o el tamaño de ventana son ilegibles por separado (distinto de la barra del #3, que necesita ambos) | `.context_window.*` |

## Por qué tokens absolutos y no %

> Why absolute tokens and not % of window: quality degrades at an absolute size, not a
> proportional one. 366k is a lot of context whether the window is 200k or 1M.
> Why the bar tops out at RED_K: it is a risk gauge, not a fuel gauge.
> The ┋ mark is where auto-compact will fire, so you can see the two limits at once.

## Variables ajustables

Variables de entorno que lee el encabezado del script, por ejemplo en `"env"` de
`settings.json`:

- `CC_CTX_GREEN_K` — sobrescribe el umbral `context-amber` (por defecto: thresholds.json)
- `CC_CTX_RED_K` — sobrescribe el umbral `context-red` (por defecto: thresholds.json)
- `CC_BAR_WIDTH` — ancho de la barra en caracteres (por defecto 20)
- `CC_STATE_DIR` — dónde se escribe el snapshot de `/ahora` (por defecto `~/.claude/state`)
- `CC_NOW` — sobrescribe el "ahora" en segundos epoch, usado solo por `--selftest`

## Más

Ver `docs/statusline-internals.md` para el cambio de payload de la 2.1.275
(`.permission_mode` desapareció, por qué produjo `❄true%/0` y un falso "sin HANDOFF"),
la definición exacta de la deriva, y el procedimiento para volver a capturar una muestra
del payload cuando Claude Code lo cambie de nuevo.
