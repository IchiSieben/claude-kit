# thresholds.json

Fuentes: `home/.claude/rules/thresholds.json` (archivo completo),
`docs/statusline-internals.md` §Thresholds, `home/.claude/statusline.sh`,
`home/.claude/hooks/session-drift-warn.sh`, `tests/statusline_test.sh`.

## El único lugar donde viven los números

El propio `_readme` de `rules/thresholds.json` plantea la regla que el
archivo hace cumplir: el código busca los umbrales por `id`, nunca por
posición; un archivo faltante o ilegible no es licencia para caer a un valor
fijo en el código — la barra imprime en su lugar el aviso ámbar
`⚠ umbrales` y deja de colorear y de dar consejos, "porque un umbral que no
se puede leer no es lo mismo que un umbral que no se cruzó".

## Todas las entradas

Los valores de abajo son los vigentes según la línea `confirmed` del
archivo: `2026-09-18 — owner confirmed every value below unchanged from
statusline.sh`.

| id | mide | condición | valor | prioridad | acción |
|---|---|---|---|---|---|
| `quota-5h` | cuota de 5 horas usada | `five_pct >=` | 90 | 10 | parar, o bajar a `sonnet` |
| `context-red` | tamaño del contexto | `context_k >=` | 300 (k tokens) | 20 | `/handoff` primero, después `/clear` |
| `cache-cooling` | minutos que le quedan a una caché viva | `cache_left_min <=` | 5 | 25 | un turno corto para recalentar, o `/handoff` si vas a parar (`-1` cuando está fría, así que nunca dispara sobre una caché fría) |
| `cache-cold` | hit rate de la caché de prompt | `cache_pct <` | 60 | 30 | nombrar la causa (o `/usage` si no se sabe); la pista ya no repite «frío» |
| `session-long` | duración de la sesión | `session_min >=` | 480 (8h) | 40 | `/handoff` antes de `/clear` (condicionado a `context-amber`) |
| `unpushed` | commits sin pushear | `ahead >` | 0 | 50 | `git push` (`param: 7200`s de gracia antes de que el contador se ponga ámbar) |
| `context-amber` | tamaño del contexto | `context_k >=` | 150 (k tokens) | 60 | solo banda, sin consejo |
| `cache-hit-ok` | hit rate de la caché de prompt | `cache_pct >=` | 85 | 65 | solo banda: desde ese valor la barra oculta `hit N%` (era un 85 fijo en el script) |
| `handoff-drift-files` | archivos sucios más nuevos que HANDOFF.md | `handoff_dirty >` | 20 | 70 | solo banda, sin consejo |
| `handoff-drift-sessions` | sesiones desde HANDOFF.md | `handoff_sessions >=` | 2 | 71 | solo banda, sin consejo |

La prioridad es "el número más bajo dispara primero": la barra muestra un
solo consejo, el de menor `priority` entre los umbrales cuya condición
cumple en ese momento. Las entradas con `hint: false` (`context-amber` y las
dos `handoff-drift-*`) solo condicionan color u otro umbral — el campo
`gate` de `session-long`, por ejemplo, exige que `context-amber` también se
cumpla para que su consejo dispare.

Una métrica que el llamador no pudo medir se reporta como `-1` y nunca
cumple ninguna condición — lo desconocido a propósito no es lo mismo que
cero.

## Labels y las bandas visor-*

`labels` (al nivel de `thresholds`) guarda las tres palabras del segmento de caché:
`cache-warm` → `caliente`, `cache-cooling` → `enfriando`, `cache-cold` → `fría · próximo turno
reescribe`. El texto que muestra la barra también es dato: sin ese bloque, la barra imprime
solo `⚡`/`❄` y el número.

Las entradas `visor-*` (prioridad 200 en adelante, todas `hint: false`) son el semáforo del
visor de [enjambre](https://github.com/IchiSieben/enjambre). La barra nunca mide sus métricas
(`disk_used_pct`, `mem_used_pct`, trabajos), así que para ella son inertes.

## Quién lo lee

`home/.claude/statusline.sh` (la barra), `home/.claude/hooks/session-drift-warn.sh`
(el aviso de deriva en `SessionStart`) y `/ahora`. Ninguno de los tres lleva
un número de umbral en su propio código; los tres buscan
`rules/thresholds.json` por id en tiempo de ejecución.

## Archivo faltante o ilegible

Ambos casos están probados en `tests/statusline_test.sh` y terminan en el
mismo resultado: sin bandas, sin consejos, nunca un valor por defecto
recordado.

- **Archivo faltante**: `statusline.sh` reporta `TH_FILE=""` y la barra
  imprime `⚠ umbrales`.
- **Archivo presente pero no parseable** (el test escribe un JSON truncado o
  inválido): la barra igual sale con 0, igual imprime `⚠ umbrales`, y no da
  ningún consejo que se pueda confundir con uno real (el test verifica que
  ni "`/handoff`" ni el texto "límite 5h" aparezcan en ese caso). `/ahora`
  reporta "no puedo leer los umbrales" en lugar de sus tres líneas normales
  de estado.

`session-drift-warn.sh` sigue la misma regla por su cuenta: si
`rules/thresholds.json` no se puede leer o `jq` no logra sacar de ahí las
dos condiciones de deriva, el hook sale en silencio en vez de avisar — no
hay banda roja calculable, así que no se afirma ninguna.

## Cómo cambiar un umbral

1. Editar el valor (o `condition`/`priority`/`actions`) en
   `home/.claude/rules/thresholds.json`, y actualizar su línea `source` si
   cambió la justificación.
2. Correr `bash tests/statusline_test.sh` y `bash tests/hooks_test.sh`.
3. Correr `sync-to-home.sh` para reflejar la copia editada del repo hacia
   `~/.claude/` (`sync-to-home.sh` copia exactamente lo que imprime `mirror_list` en
   `mirror-lib.sh`, y esa lista incluye `rules/*.json`, así que el archivo viaja con el
   resto del espejo).

## Overrides por variable de entorno

`CC_CTX_GREEN_K` y `CC_CTX_RED_K` sobrescriben `context-amber` y
`context-red` respectivamente en tiempo de ejecución, sin tocar el JSON —
`statusline.sh` los lee directamente antes de consultar el archivo de
umbrales.

## Viaja en el espejo

`mirror-lib.sh` incluye `rules/*.json` (junto con `rules/*.md`, `hooks/*.sh`
y `agents/*.md`) en el conjunto de archivos que copia entre el repo y
`~/.claude/`, así que `rules/thresholds.json` nunca es un archivo que se
edite en un solo lado y no en el otro.
