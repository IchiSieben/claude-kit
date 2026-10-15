---
lesson:
  route: code-like-me
  order: 7
  level: 2
---

# Reviewer: un modelo más fuerte, un contexto nuevo

## Revisor >= autor, nunca más débil

Un modelo que revisa su propia salida muestra sesgo de auto-preferencia medible; uno
distinto y al menos igual de fuerte, no. Por eso el agente `reviewer` está pineado a
`opus`/`high` sin importar qué modelo escribió el código, y por eso la revisión cruzada
entre proveedores tiene una dirección permitida: Claude puede revisar código de Gemini, y
Gemini 3.1 Pro (high) puede hacer una segunda pasada sobre código de Claude, pero los
modelos Claude dentro de Antigravity nunca deben revisar código de Claude — es el mismo
linaje de proveedor revisándose a sí mismo.

Fuente: `home/.claude/agents/reviewer.md` (comentario sobre el procedimiento); `home/.claude/MANUAL.md`
§5 ("Revisor ≥ autor... cadena de revisión cruzada permitida").

## Contexto nuevo, caché propia

`reviewer` solo tiene `Read, Grep, Glob, Bash(git *)` — de solo lectura, no puede editar
archivos. Corre en su propio contexto de subagente, con su propia caché de prompt, así que
lanzarlo no toca la caché de la sesión padre como sí lo haría cambiar el modelo de la
sesión con `/model`. Esa es la razón concreta por la que la regla 6 de ruteo
(`docs/routing.es.md`) dice que nunca se cambia el modelo de la sesión para conseguir un
review.

Fuente: frontmatter de `home/.claude/agents/reviewer.md` (`tools:`, descripción);
`home/.claude/CLAUDE.md` §Routing regla 6.

## Por qué el auto-review del mismo modelo no es una compuerta válida

La evidencia que cita el kit: el auto-review del mismo modelo está sesgado hacia la
aprobación (Panickssery 2024). Usar un revisor distinto y al menos igual de fuerte, con una
rúbrica de elección forzada, es práctica propia del kit, todavía sin paper que la respalde —
ver `docs/references.es.md` para lo verificado y `docs/references-candidates.es.md` para el
rastro de búsqueda de la cita que llevaba antes. Por eso tanto `reviewer` como `/xreview` usan
una rúbrica donde ninguna dimensión se puede saltear, en vez de comentario libre.

Fuente: `home/.claude/skills/xreview/SKILL.md` (línea Evidence).

## `/xreview`: review cruzado, paso a paso

`xreview` tiene dos modos, invocados como `pack` o `ingest`; no se dispara solo a partir de
una descripción (`disable-model-invocation: true`).

**`pack`:**
1. Recolecta `git diff main...HEAD` (o el diff staged), `SPEC.md`, el comando de test y su
   última salida.
2. Escribe `review/REQUEST-<fecha>.md`: contexto en <=10 líneas, el diff (o una lista de
   archivos si supera las 800 líneas), y la rúbrica de abajo. Instruye al revisor externo a
   ser de solo lectura y a escribir su reporte en `review/REPORT-<tool>-<fecha>.md`.
3. Corre el revisor externo y guarda su salida. Para el CLI `agy` de Antigravity en modo
   headless: auditorías de todo el repo o arquitectónicas usan `gemini-3-1-pro` en high
   effort (1M de contexto, linaje independiente); un diff acotado usa
   `gemini-3-8-flash-high` (rápido, pool de cuota separado de Claude). Los modelos Claude de
   Antigravity nunca deben revisar código escrito por Claude. Si `agy` no está instalado o
   falla, hay que decirlo y parar — nunca caer en silencio a revisarlo uno mismo.
   Alternativa con Codex: `codex exec --sandbox read-only`.

**`ingest <ruta-al-reporte>`:**
1. Lee el reporte.
2. Verifica cada hallazgo contra el código real (abriendo el `file:line`) y lo clasifica:
   confirmado / no reproducible / en desacuerdo (con razón).
3. Los hallazgos confirmados van a "Next steps" del HANDOFF.md con un comando de
   verificación cada uno; los desacuerdos van con una línea cada uno para que el owner
   arbitre.
4. Nunca se aplica en bloque la reescritura del revisor — se corrige el gap confirmado con
   el diff más chico posible.

Fuente: `home/.claude/skills/xreview/SKILL.md`.

## La rúbrica (tanto `reviewer` como `/xreview`)

Elección forzada por dimensión — pass / concern / fail — con evidencia `file:line`, sin
prosa sin ubicación:

| Dimensión |
|---|
| Correctitud contra los invariantes del SPEC |
| Modos de falla no manejados (input vacío, concurrencia, auth, escrituras parciales) |
| Seguridad (inyección, secretos, path traversal, permisos) |
| Duplicación agregada / consolidación o deuda de refactor saltada |
| Qué NO cubren los tests |

`reviewer` además lee `SPEC.md` y corre el comando de test del proyecto, citando las
últimas 15 líneas, y cierra con "¿Lo mergearía? sí / no, porque <una línea>." Si una
dimensión está bien, la frase exigida es "pass — checked <qué>" — nunca se inventan
hallazgos para parecer riguroso, y los pass nunca se rellenan con elogios.

Fuente: `home/.claude/agents/reviewer.md`; `home/.claude/skills/xreview/SKILL.md` (Rubric).

## `templates/REVIEW.md`

La plantilla que se espera que llene un reporte de review: un checkbox de veredicto
(mergear tal cual / mergear con arreglos / devolver — no cumple SPEC.md), una lista de
Findings (`file:line` — qué está mal, por qué importa), una línea de chequeo de seguridad
(sin secretos, sin credenciales, sin path traversal, sin scope creep más allá de los
archivos permitidos por la tarea) y, si no se mergea, una lista de "Sent back for" con
exactamente qué corregir.

Fuente: `templates/REVIEW.md`.

## Lo que el reviewer NO debe hacer

Reportar solamente — nunca editar archivos, nunca arreglar lo que encuentra, nunca inventar
hallazgos para parecer riguroso, nunca elogiar una dimensión que pasó. Tanto
`home/.claude/agents/reviewer.md` como el skill `/xreview` lo dicen de forma explícita, y el
paso 4 de `/xreview ingest` lo extiende: incluso después de que un humano decide que un
hallazgo está confirmado, el arreglo se aplica a mano como el diff más chico posible —
nunca pegando la reescritura del propio revisor.

Fuente: `home/.claude/agents/reviewer.md` ("Report only. Do not edit files."); `home/.claude/skills/xreview/SKILL.md`.
