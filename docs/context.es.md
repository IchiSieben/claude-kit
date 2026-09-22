# Higiene de contexto

Fuentes: `home/.claude/rules/context-hygiene.md`,
`home/.claude/rules/thresholds.json`, `home/.claude/settings.json`,
`home/.claude/statusline.sh`, `home/.claude/MANUAL.md` cap. 2,
`home/.claude/CLAUDE.md` §Status line.

## Trabajar entre ámbar y rojo, en tokens absolutos

La banda de trabajo se define con dos ids en `rules/thresholds.json`:

- `context-amber` — hoy `150` (miles de tokens, `context_k >= 150`).
- `context-red` — hoy `300` (miles de tokens, `context_k >= 300`).

Por debajo de ámbar: seguir. Entre ámbar y rojo: todavía bien, pero conviene
planear un hito para compactar. En rojo: proponer `/handoff` primero, después
`/clear`. `/compact` solo si el mismo hilo tiene que continuar. Ninguno de
los dos números está escrito en `statusline.sh` ni en ningún hook — ambos
leen el JSON por id, así que hay un solo lugar donde cambiarlos.

## Por qué el porcentaje de la ventana es la regla equivocada

`rules/context-hygiene.md` lo dice de forma directa: *"Percentage of the
window is NOT the rule: 60% of 1M is twice the red band."* La calidad cae
con el tamaño absoluto del contexto, no con la proporción — 300k tokens son
muchos tokens tanto en una ventana de 200k como en una de 1M. El propio
comentario de cabecera de `statusline.sh` dice lo mismo: *"Why absolute
tokens and not % of window: quality degrades at an absolute size, not a
proportional one. 366k is a lot of context whether the window is 200k or
1M."*

## `┋` marca el techo del auto-compact

`home/.claude/settings.json` fija `env.CLAUDE_CODE_AUTO_COMPACT_WINDOW` en
`400000`. La barra de estado marca ese punto como `┋`. Queda por encima de
`context-red` (300k) a propósito: la cabecera de `statusline.sh` describe la
barra como *"a risk gauge, not a fuel gauge"* — la marca `┋` muestra dónde va
a disparar el auto-compact para ver los dos límites a la vez, pero la banda
roja en 300k es donde se espera que el usuario actúe primero. Compactar es
un evento con pérdida que se programa a propósito después de un handoff, no
algo que le debería pasar a la sesión porque nadie miró la barra.

## En rojo: `/handoff` primero, después `/clear`

De `home/.claude/CLAUDE.md` §Status line:

| Señal | Acción propuesta |
|---|---|
| contexto en banda roja | `/handoff` PRIMERO, después `/clear` — `/compact` solo si el hilo tiene que continuar |

`/clear` es reversible y deja la sesión anterior resumible; `/compact` no lo
es, así que se reserva para cuando el hilo realmente tiene que seguir.

## Compactar en hito le gana a compactar en emergencia

De `rules/context-hygiene.md`: compactar después de aprobar un plan, después
de que los tests pasen, o antes de empezar una tarea no relacionada — no
solo cuando la banda roja obliga. Esperar a la banda roja o al auto-compact
es elegir el peor momento posible para perder contexto.

## Nunca pegar logs, datasets ni HTML enteros

Resumir a un máximo de 20 líneas, con las líneas exactas que importan. La
regla aplica igual a logs, datasets y HTML crudo — es sobre el volumen que
entra al contexto, no sobre el formato de la fuente.

## Una tarea por sesión

Una pregunta no relacionada a mitad de sesión es señal de usar `/btw` o
`/clear`, no de seguir trabajando dos objetivos distintos en el mismo
contexto.
