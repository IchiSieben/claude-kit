# harvest, partidas y bitacora

Fuentes: `harvest.py`, `partidas.py`, `bitacora.py`, `SPEC-partidas.md` (con su sección
"Facts measured"), `docs/bitacora-spec.es.md`, `tests/partidas_test.sh`, `tests/bitacora_test.sh`,
`home/.claude/rules/thresholds.json`, `home/.claude/rules/models.json`.

## Qué es

- `harvest.py` guarda métricas de los transcripts de Claude Code antes de que el barrido de
  30 días los borre.
- `partidas.py` convierte esas métricas en "sesiones como partidas": por sesión, cuáles de
  cuatro hábitos que enseña el kit se rompieron, más totales por semana y por proyecto.
- `bitacora.py` responde "dónde quedó cada proyecto y por dónde retomo".

Los tres corren en local, usan solo la biblioteca estándar y solo leen `~/.claude`. No suben
nada.

## Cómo correrlo

Ejecuta los comandos desde la raíz del repo, donde están los tres scripts.

```
python harvest.py
python partidas.py
python bitacora.py
```

| Comando | Escribe en `~/claude-archive/` |
|---|---|
| `harvest.py` | `sessions.json`; `sessions.v1-backup.json` (se copia una sola vez, en la primera corrida v2) |
| `partidas.py` | `partidas.json`, `partidas.html`, `partidas.txt` |
| `bitacora.py` | `bitacora.html`, `bitacora.json` |

`partidas.py` lee `sessions.json`, así que corre antes `harvest.py`. Si `sessions.json` no se
puede leer, `partidas.py` se detiene y lo dice.

Opciones:

| Opción | Aplica a | Efecto |
|---|---|---|
| `--claude-dir DIR` | los tres | Carpeta de configuración de Claude. Por defecto `$CLAUDE_CONFIG_DIR`, si no `~/.claude`. |
| `--out DIR` | `harvest.py`, `bitacora.py` | Carpeta de salida. Por defecto `~/claude-archive`. |
| `--archive DIR` | `partidas.py`, `bitacora.py` | Dónde está `sessions.json` (y, en `partidas.py`, dónde escribe). Por defecto `~/claude-archive`. |
| `--report-only` | `harvest.py` | Muestra lo que hay en el archivo; no lee reglas ni escribe. |
| `--weeks N` | `partidas.py` | Largo de la ventana. Por defecto 4. |
| `--now ISO` | `partidas.py`, `bitacora.py` | Fija "hoy". Lo usan las pruebas. |
| `--root DIR` | `bitacora.py` | Carpeta cuyas subcarpetas son los proyectos. Por defecto, la carpeta que contiene el repo. |
| `--dry-run` | `bitacora.py` | Lista los proyectos detectados y la fuente de cada campo; no escribe. |
| `--include-prompts` | `bitacora.py` | Incluye además el texto del último prompt en `bitacora.json`. |

`bitacora.py` acepta también `--projects FILE` y `--visor-dir DIR`.

Pruebas:

```
bash tests/partidas_test.sh
bash tests/bitacora_test.sh
```

Ambas generan datos sintéticos en un directorio temporal y no leen el home real.

## Qué cambió en v2 y por qué

Se midieron dos hechos sobre 153 transcripts (2026-10-15).

**Uso duplicado.** Claude Code guarda un registro por cada bloque de contenido de un mensaje
del asistente, y todas las copias traen el mismo `message.usage` (5 674 grupos duplicados,
ninguno con valores distintos). v1 sumaba todas las copias, así que sus tokens salían
inflados, hasta cerca de 2x. v2 cuenta cada `message.id` una vez; un registro sin id cuenta
una vez. Las sesiones que solo existen en el archivo (su transcript ya no está) conservan su
registro y sus números de v1. Quedan marcadas como solo-v1, se cuentan en el reporte y nunca
se juzgan.

**Costo.** Los mensajes no traen costo. Un registro `cost-state` trae un `costUSD`
acumulado y monótono por modelo (114 de 114 archivos con ese registro lo cumplen). v2 usa el
último `cost-state`: `cost_source: "harness"`. Si la sesión no tiene ninguno, estima con los
precios de `models.json`: `cost_source: "estimate"`.

La estimación es una cota inferior. Frente a la cifra del harness midió 0,28-1,0x sin los
transcripts de subagentes y 0,6-1,0x sumándolos. La diferencia no está explicada. Las
llamadas al advisor, las herramientas del lado del servidor y las sesiones reanudadas son
candidatas; ninguna está confirmada. No leas una estimación como el costo real.

Las escrituras de caché se valoran con `cache_creation.ephemeral_5m/1h_input_tokens` cuando
existen; si no, todas al precio de 5 minutos. Un modelo ausente de `models.json` vale 0, no se
adivina.

## Campos por sesión

Se conservan todas las claves de v1. v2 agrega:

| Campo | Significado |
|---|---|
| `harvest_version` | `2`. |
| `project_label` | Nombre de carpeta del `cwd` más frecuente; `home` si es el directorio home. |
| `bytes` | Tamaño del `.jsonl` principal más sus `subagents/*.jsonl`. |
| `turns` | Prompts escritos por la persona, sin sidechain, meta ni comandos. |
| `commands` | Conteo de `/clear`, `/compact`, `/handoff`. Una llamada `Skill` a `handoff` cuenta como `/handoff`. |
| `compactions` | Cantidad de registros `compact_boundary`. |
| `compactions_without_handoff` | Compactaciones sin handoff desde la compactación anterior o desde el inicio. |
| `models`, `subagents` | Tokens y peticiones por modelo, deduplicados por `message.id`; cadena principal y transcripts de subagentes. |
| `cost_usd`, `cost_source` | Costo y su origen: `harness`, `estimate` o `none`. |
| `peak_context` | Mayor `input + cache_read + cache_write` de una petición de la cadena principal. |
| `hit_pct` | `100 * cache_read / (input + cache_read + cache_write)` sobre la cadena principal. |
| `cold_cache_events` | Peticiones de la cadena principal cuyo hit propio queda bajo `cache-cold`, sin contar la primera ni la primera después de una compactación o `/clear`. |
| `active_ms` | Suma de los registros `turn_duration`. |
| `duration_min` | Último timestamp menos el primero, en minutos. |
| `start_hour_local` | Hora local (0-23) del primer timestamp. |

## Las cuatro jugadas

`partidas.py` solo juzga sesiones con `harvest_version == 2`. Cada jugada en la salida nombra
su regla y los números que la dispararon.

| Jugada | Se dispara cuando | De dónde sale el número |
|---|---|---|
| `long-no-handoff` | `peak_context >= context-red * 1000` y el conteo de `/handoff` es 0 | `thresholds.json`, id `context-red` (300 k al escribir esto) |
| `strong-on-mechanical` | El modelo con más tokens de salida tiene `tier` `frontier` o `flagship`; al menos 5 llamadas a herramientas; al menos 80 % de ellas en `Read, Grep, Glob, Bash, PowerShell, WebFetch`; ninguna llamada a `Edit`, `Write`, `NotebookEdit`, `Agent` ni `Task` | `models.json`, campo `tier`. El 5 y el 80 % están escritos en el código. |
| `cold-cache` | `cold_cache_events > 3` | `thresholds.json`, id `cache-cold` (hit bajo 60 % al escribir esto). El 3 está escrito en el código. |
| `compact-no-handoff` | `compactions_without_handoff >= 1` | Ninguno; es un conteo. |

`strong-on-mechanical` es una heurística. Deduce el tipo de trabajo por la mezcla de
herramientas y no ve la intención. Un acierto es una pregunta, no un veredicto.

El código no tiene valor numérico de respaldo para umbrales ni precios. Si no se puede leer
`thresholds.json` o `models.json` ni en `<claude-dir>/rules/` ni en la copia del kit, o si un
`thresholds.json` instalado no trae `context-red`, `cache-cold` o `cache-hit-ok`, el script
nombra el archivo y termina con código 2. Es la misma regla de la barra de estado: un umbral
que no se puede leer no es un umbral que no se cruzó. Ver `docs/thresholds.es.md`.

## Privacidad

`partidas.json`, `partidas.html` y `partidas.txt` llevan solo la etiqueta del proyecto. Nunca
llevan el directorio codificado, la ruta del archivo, el `cwd`, el id de sesión, el texto de
los prompts ni el nombre de usuario. Las sesiones se numeran de 1 a N por hora de inicio. Una
etiqueta que cumpla la expresión regular extendida de `$KIT_PROTECTED_PATHS` se muestra como
`privado-N` (sin definir: ninguna coincide). Las pruebas verifican estas ausencias y que el
HTML no contenga ninguna referencia `http`.

`sessions.json` guarda solo metadatos: ni contenido de mensajes ni texto de prompts. Aun así
conserva las rutas `file` y `project`, así que es el archivo local, no algo para publicar.

`bitacora.json` omite el texto de los prompts salvo que pases `--include-prompts`.
`bitacora.html` es solo para ti: muestra el último prompt de cada proyecto y enlaces a
carpetas locales, por lo que no se publica. La página no hace ninguna petición de red.

## Disco

Los transcripts crecen hasta que el barrido los borra. `partidas.py` informa el tamaño de
todos los archivos bajo cada `projects/<dir>/` (incluidos los transcripts de subagentes),
agrupado por etiqueta de proyecto y de mayor a menor (`disk_by_project`). Un directorio sin
ninguna sesión legible aparece como `sin-sesiones`.

## Relación con el visor de enjambre

El visor de enjambre muestra nodos, cola, sesiones en vivo, cuota y tokens por día. La
bitácora no lo repite: da un número de 30 días (tokens y costo) por proyecto y enlaza al
visor. `partidas` es la vista semanal y agregada: cómo se movieron los hábitos y el costo en
las últimas semanas, no qué está corriendo ahora.

## Límites

- El barrido de 30 días vuelve una muestra cualquier ventana más antigua. `partidas.py` se
  niega a comparar ventanas que el archivo no cubre por completo.
- `turns` cuenta solo prompts escritos. Quedan fuera los resultados de herramientas, los
  comandos y los prompts de sidechain, así que no mide esfuerzo ni producción.
- Las horas son locales. `start_hour_local` y la semana ISO de `by_week` usan la zona horaria
  de la máquina.
- El costo de las sesiones `estimate` es una cota inferior (ver arriba), y las sesiones
  solo-v1 tienen tokens inflados y no se juzgan.
