---
lesson:
  route: code-like-me
  order: 8
  level: 1
---

# El manual, `/ahora` y dónde viven los números

## `home/.claude/MANUAL.md`: siete capítulos, cargados bajo demanda

| # | Capítulo |
|---|---|
| 1 | Carriles y ruteo |
| 2 | Ciclo de vida de una sesión |
| 3 | HANDOFF |
| 4 | Glosario de la barra de estado |
| 5 | Delegación |
| 6 | Seguridad |
| 7 | Costos y cuota |

`/manual` imprime este índice tal cual; `/manual <1-7>` imprime un capítulo tal cual. El
skill `manual` resuelve el archivo por su cuenta (`~/.claude/MANUAL.md`, espejado en cada
máquina, con fallback a la copia del repo) y es explícito en que no debe resumir, acortar ni
"mejorar" la salida — quien lee está chequeando la regla exacta y su línea `Fuente:`.

Fuente: `home/.claude/MANUAL.md` (índice); `home/.claude/skills/manual/SKILL.md`.

## Por qué el manual nunca se carga por sesión

`CLAUDE.md` se relee en cada sesión y lleva un comentario que lo topea en menos de 70
líneas, y aclara explícitamente que eso es un *presupuesto de contexto, no una regla de
estilo* — se achica cortando prosa, nunca cortando una regla, y toda regla ahí adentro tiene
que rastrearse a una falla repetida. `MANUAL.md` son unas 500 líneas en español escritas
para una persona, no para el modelo, y a propósito no se importa con `@`: hacerlo cargaría
esa cantidad de texto en cada sesión por contenido que solo lee el owner.

Fuente: `home/.claude/CLAUDE.md` (comentario de cabecera, líneas 2-3); `docs/statusline-internals.md`
§"The manual".

## La división: CLAUDE.md es el qué, MANUAL.md es el porqué

La propia cabecera de `CLAUDE.md` lo dice directo: *"El PORQUÉ detrás de cada regla de
abajo, con ejemplos y preguntas abiertas: MANUAL.md... Las reglas viven ACÁ; si los dos no
coinciden, este archivo gana y el manual está desactualizado."* `CLAUDE.md` y `rules/`
llevan lo que el modelo tiene que obedecer; `MANUAL.md` lleva el porqué y el ejemplo
trabajado, para una persona. Nada que el modelo tenga que HACER puede vivir solo en el
manual — si viviera ahí, el modelo nunca lo vería. El skill `manual` repite la misma regla
del lado de la lectura: nunca responder una pregunta de reglas de memoria cuando el manual
la cubre, imprimir el capítulo en su lugar.

Fuente: `home/.claude/CLAUDE.md` (comentario de cabecera, línea 3); `home/.claude/skills/manual/SKILL.md`
§Rules; `docs/statusline-internals.md` §"The manual".

## `/ahora`: el estado de ahora, una acción, el umbral detrás

`/ahora` corre `statusline.sh --ahora`, el mismo evaluador que usa la barra, así que los dos
nunca pueden dar consejos distintos — es la regla de la capa del capítulo 1 aplicada a la
propia barra: un modelo no tiene que HACER esto, solo mostrarlo. Imprime exactamente tres
líneas y se detiene: (1) `ahora:` los números que la barra vio por última vez y qué tan
vieja es esa muestra, (2) `hacé:` la acción del único umbral de mayor prioridad que está
cruzado ahora mismo, y (3) `por qué:` qué umbral, su condición, y el archivo del que sale.

No puede leer la cuota desde los transcripts porque la cuota de 5h y la tasa de acierto de
caché existen solo dentro del propio payload JSON de la barra de estado — no se escriben en
el transcript de la conversación en absoluto. Por eso `/ahora` lee la última muestra de la
barra para el directorio actual (un skill no recibe `$CLAUDE_SESSION_ID`, confirmado por
medición) en vez de calcular algo a partir del historial, y una muestra vieja significa que
los números que reporta son viejos, cosa que la línea dice explícitamente.

Fuente: `home/.claude/skills/ahora/SKILL.md`.

## `rules/thresholds.json`: el único lugar donde viven los números

El manual lo dice sobre sí mismo, textual en su propia cabecera:

> "Los umbrales que aparecen en los capítulos 2, 4 y 7 no están escritos en este manual ni
> en el código: viven en `rules/thresholds.json`, que es lo que leen la barra, los hooks y
> `/ahora`. Si un número de acá no coincide con ese archivo, el archivo tiene razón."

`thresholds.json` lleva el mismo contrato en su propio bloque `_readme`: cada entrada tiene
un `id` estable (se busca por id, nunca por posición), una `priority` (menor dispara
primero, y la barra muestra solo la coincidencia de menor prioridad), una `condition` y un
`source` — "Sin source = está inventado y hay que borrarlo". Una métrica que no se pudo medir
se lee como `-1` y nunca matchea, porque lo desconocido nunca debe parecer cero. Un archivo
faltante o ilegible no es licencia para caer a un valor por defecto fijo en el código: la
barra imprime un `⚠ umbrales` en ámbar y deja de colorear y de sugerir en su lugar.

Fuente: `home/.claude/MANUAL.md` (cabecera, líneas 18-20); `home/.claude/rules/thresholds.json`
(`_readme`).

## `Fuente:` y `[PENDIENTE]` como funcionalidad, no como hueco

Toda regla del manual lleva una línea `Fuente:` con el archivo del que salió. Una regla sin
fuente se trata como inventada y hay que borrarla — `verify.sh` lo audita. Lo que todavía no
se decidió de verdad se marca `[PENDIENTE]` y nunca se resuelve a ojo; el skill `manual` lo
repite explícitamente: las marcas `[PENDIENTE]` son reales, significan que la decisión nunca
se tomó, y una pregunta sobre una de ellas se reporta como pendiente, no se responde. Dos de
esos ítems estaban abiertos en el manual y se cerraron el 2026-09-18 (la banda de contexto y
la acción por defecto después de un handoff); dos siguen abiertos al momento de escribir
esto: cuándo aplica `opusplan` (capítulo 1) y el presupuesto de gasto (capítulo 7).

Es una disciplina deliberada, no un pendiente que al kit no le dio tiempo de resolver:
mantiene cada afirmación rastreable y evita que el modelo fabrique una respuesta que suena a
decisión sobre algo que en realidad nadie resolvió.

Fuente: `home/.claude/MANUAL.md` (párrafo de apertura y las secciones `[PENDIENTE]` de
ambos capítulos); `home/.claude/skills/manual/SKILL.md` §Rules; `docs/statusline-internals.md`
§"The manual".
