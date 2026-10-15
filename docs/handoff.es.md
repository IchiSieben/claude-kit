---
lesson:
  route: code-like-me
  order: 4
  level: 1
---

# HANDOFF.md y la deriva

## Qué es

`HANDOFF.md`, en la raíz del repo, es la memoria de la sesión: estado,
decisiones, qué falló y próximos pasos, escrito para que una sesión nueva
pueda continuar sin tener que re-explorar el código ni releer la
conversación. Lo escribe la skill `handoff`
(`home/.claude/skills/handoff/SKILL.md`) antes de cerrar, antes de
compactar, o cuando el contexto llega a la banda roja de
`rules/thresholds.json`.

Secciones fijas, con estos encabezados exactos:

```markdown
# HANDOFF — <project>  (updated: <ISO date>)

## Goal (1-2 lines)
## Current state
- DONE: ...
- IN PROGRESS: <step> — <exactly where it stopped, file:line if relevant>
- BLOCKED: ...
## Decisions (with the reason, one line each)
## Tried and failed (so nobody retries it)
## Next steps (ordered, each with its verification)
1. ...  → verify: `<command>`
## Commands that matter
- test: ...
- run: ...
## Open questions for the owner
```

Reglas de la skill: solo hechos, sin narrativa (todo lo derivable del código
o de `git log` se queda afuera); "IN PROGRESS" tiene que permitir continuar
sin leer la conversación; máximo 120 líneas, el detalle viejo se muda a
`docs/handoffs/YYYY-MM-DD.md`; después de escribir, imprimir
`git status --short` y recordar commitear `HANDOFF.md` si el proyecto lo
versiona.

## `verify.sh` corre primero, en cada sesión

`verify.sh` comprueba lo que el `HANDOFF.md` actual afirma como hecho, no lo
que dice de palabra. El comentario de cabecera da la razón directamente: un
HANDOFF que afirma algo falso es peor que no tener ninguno, porque encima se
planifica — esto ya pasó una vez, cuando un HANDOFF decía que una
herramienta no estaba instalada cuando llevaba tres semanas instalada, y
costó dos pasos de plan que sobraban. El script sale con 0 solo si pasan
todas las comprobaciones.

## Deriva: una sola definición

La deriva tiene exactamente una definición: `drift_scan` dentro de
`home/.claude/statusline.sh`, expuesta como `statusline.sh --drift <dir>`,
que imprime cinco campos en una línea:

```
state hage f c s
```

- `state` — `ok` (nada se movió desde que se escribió `HANDOFF.md`), `stale`
  (hay deriva) o `none` (no hay `HANDOFF.md`).
- `hage` — horas desde el mtime de `HANDOFF.md`.
- `f` — archivos sucios más nuevos que `HANDOFF.md`.
- `c` — commits desde el mtime de `HANDOFF.md`.
- `s` — sesiones iniciadas para este proyecto desde entonces, leídas de
  `~/.claude/logs/events.jsonl`.

Tanto `session-drift-warn.sh` (el hook de `SessionStart`) como la barra de
estado llaman a esta misma función, así que no pueden contradecirse.

## La banda roja vive en `rules/thresholds.json`, no en el código

La deriva se pone roja en los umbrales `handoff-drift-files` y
`handoff-drift-sessions` definidos en `home/.claude/rules/thresholds.json`
— hoy `> 20` archivos sucios o `>= 2` sesiones. Ni la barra ni el hook
llevan esos números escritos; ambos leen las mismas entradas del JSON por
id.

## Un commit que solo toca HANDOFF.md no cuenta

Commitear el propio handoff no cambia el mtime de `HANDOFF.md` respecto de
sí mismo, pero `drift_scan` excluye explícitamente del conteo `c`
(commits-desde) a un commit cuyo único archivo cambiado sea `HANDOFF.md`.
Sin esta regla la barra se pondría vieja apenas se commitea un handoff —
justo cuando está más fresco.

## Los contadores muestran `?`, nunca `0`

Cualquiera de `f`, `c`, `s` que no se pueda calcular muestra `?`. Nunca baja
a `0` ni al estado `none` — `none` significa que el archivo directamente no
existe, no que un contador falló al calcularse.

## Después de un handoff: `/clear` por defecto

Una vez escrito `HANDOFF.md` y con la deriva fresca, `/clear` es lo por
defecto — es reversible y la sesión anterior queda resumible. `/compact` se
usa solo cuando el mismo hilo tiene que continuar; es una operación con
pérdida, así que se programa a propósito, no se usa por costumbre.

## El draft de PreCompact deja el criterio en blanco a propósito

`precompact-draft.sh` agrega hechos mecánicos a
`docs/handoffs/<fecha>-draft.md` en cada `PreCompact`: rama, commits desde el
primer `SessionStart` de la sesión, archivos sin commitear, comandos que
fallaron, y la lectura actual de deriva. De `docs/statusline-internals.md`:

> El draft junta hechos y se detiene ahí. No escribe "dónde estamos y por
> qué", porque eso es el criterio que hace que un handoff valga la pena
> leerlo, y un párrafo plausible escrito por una máquina en ese lugar es
> peor que uno en blanco — parece que alguien lo pensó. Esa parte sigue
> siendo tuya, o de `/handoff`.

El draft no podría llenar ese vacío ni queriendo: el stdout de `PreCompact`
nunca se le muestra al usuario, solo queda en el log de debug, así que el
archivo del draft es el único lugar donde ese aviso puede aparecer.
