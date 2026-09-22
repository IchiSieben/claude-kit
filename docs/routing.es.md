# Ruteo: primero la capa, después el carril

## La pregunta de la capa, primero

Antes de elegir modelo hay que preguntarse si hace falta uno. Trabajo determinista y
repetible va a código que corre sin modelo (Python/SQL/shell). Juicio, pegamento y entradas
variables van a instrucciones (skills, agentes, reglas). La pregunta que corta: *¿un modelo
tiene que HACER esto, o solo ORQUESTARLO?*

Fuente: `home/.claude/CLAUDE.md` §Routing.

## Los carriles

| Carril | Agente | Modelo | Effort | Tools | Cuándo |
|---|---|---|---|---|---|
| Trivial | `mecanico` | haiku | — | Read, Grep, Glob, Bash | Buscar, listar, leer logs, extraer, contar, renombrar |
| Mecánico | `operario` | sonnet | low | (todas) | La decisión ya está tomada; solo falta escribirla |
| Prosa | `redactor` | sonnet | medium | (todas) | READMEs, commits, informes, TDRs, traducciones |
| Recon | `investigador` | sonnet | medium | (todas) | Antes de tocar un repo que la sesión no conoce |
| Ambiguo | `profundo` | opus | xhigh | (todas) | Causa raíz no evidente, trade-offs arquitectónicos reales |

Fuente: `home/.claude/CLAUDE.md` §Routing, tabla; frontmatter de `home/.claude/agents/mecanico.md`,
`operario.md`, `redactor.md`, `investigador.md`, `profundo.md`. `mecanico` es el único de los
cinco cuyo frontmatter restringe `tools:`; los otros cuatro heredan el set completo.

Un sexto agente, `reviewer` (opus, high, tools limitadas a `Read, Grep, Glob, Bash(git *)`),
no aparece en esta tabla porque no es un carril al que se rutea trabajo ordinario — ver
`docs/reviewer.es.md`.

## Las seis reglas

1. **Recon primero.** Más de 3-4 archivos que leer: delegar a `investigador` en vez de
   leerlos en este hilo. Vuelve solo el resumen.
2. **El hilo principal decide, los subagentes ejecutan.** La sesión fija el qué y el cómo;
   la escritura se delega.
3. **`profundo` se gana, no se asume.** El disparador es la ambigüedad, no el tamaño. Un
   refactor de 20 archivos con el patrón ya definido es `operario`.
4. **No delegar lo que ya está en contexto.** Pasarle a un subagente un archivo ya leído lo
   hace más caro, no más barato.
5. **Más razonamiento en el mismo hilo: `ultrathink`**, en vez de subir el nivel de la
   sesión.
6. **Nunca cambiar el modelo de la sesión para conseguir un review.** El revisor tiene que
   ser >= el autor, pero cambiar a mitad de sesión invalida la caché de prompt; se lanza
   `reviewer` en su lugar.

Fuente: `home/.claude/CLAUDE.md` §Routing, reglas 1-6.

## El camino barato es el default

`CLAUDE_CODE_SUBAGENT_MODEL=sonnet` está fijado en `home/.claude/settings.json`. Toda
delegación, salvo que el frontmatter propio de un agente pise el modelo (como hace
`mecanico` con `haiku`, o `profundo`/`reviewer` con `opus`), ya corre en el modelo barato.
Una sesión grande con cero llamadas a subagentes no está usando esta palanca.

Fuente: `home/.claude/settings.json` (`CLAUDE_CODE_SUBAGENT_MODEL`).

## `/route`

El skill `route` (`home/.claude/skills/route/SKILL.md`) recomienda modelo, effort y modo de
ejecución (sesión principal / subagente / sesión nueva / worktree / lote `claude -p`) para
una tarea descrita, antes de arrancar el trabajo. Responde en una tabla fija (tipo, modelo,
effort, dónde, costo de caché, necesita SPEC.md, necesita plan mode, review externo después)
más una línea de razonamiento.

Su cascada barato-primero: trabajo mecánico es sonnet/medium; una feature en código conocido
es opus/high (o sonnet/high si el patrón ya existe en el repo); debugging de causa incierta
es opus/high arrancando desde un comando de reproducción; arquitectura, modelo de datos,
frontera de seguridad o corrida autónoma larga es fable/high-xhigh con plan mode y SPEC.md
primero; investigación o exploración va al subagente `Explore`; y para review, el revisor
tiene que ser al menos tan fuerte como el autor — código escrito por sonnet lo revisa opus,
por opus lo revisa fable, y por fable van tests más un review externo por CLI (un review del
mismo modelo sobre sí mismo no agrega casi nada).

El skill nombra el costo de caché de forma explícita: cada modelo (y, en la mayoría de
modelos, cada nivel de effort) tiene su propia caché de prompt, así que cambiar cualquiera de
los dos a mitad de sesión obliga a releer la conversación entera sin ningún acierto de
caché — las lecturas de caché se cobran a ~10% del input estándar, lo que hace de un cambio
avanzada la sesión la jugada más cara disponible. Sus conclusiones: nunca recomendar cambiar
el modelo de la sesión para conseguir un review (lanzar `reviewer` en su lugar); elegir
modelo y effort al arrancar la sesión, y recomendar una sesión nueva en vez de un cambio si
la tarea necesita otro; `opusplan` vuelve a cambiar el modelo en cada toggle de plan mode,
por lo que no se recomienda para sesiones largas; y `/rewind` le gana a `/compact` al
abandonar un camino, porque rewind trunca hacia un prefijo ya cacheado mientras que compact
construye uno nuevo.

Fuente: `home/.claude/skills/route/SKILL.md`.
