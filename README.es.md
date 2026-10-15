# claude-kit

Un kit personal para operar Claude Code: enrutamiento, subagentes, una puerta de revisión,
hooks y una barra de estado que mantiene `~/.claude` honesto en todas las máquinas.

![licencia](https://img.shields.io/badge/licencia-Apache--2.0-blue) ![shell](https://img.shields.io/badge/shell-bash-4EAA25) ![tests](https://img.shields.io/badge/tests-140%20passing-brightgreen) ![Claude Code](https://img.shields.io/badge/Claude%20Code-kit-5A45FF)

[English](README.md) · Español

## Qué es

Un kit personal para operar Claude Code: reglas de enrutamiento, seis subagentes, diez skills,
cinco hooks de ciclo de vida, una barra de estado y los scripts que mantienen `~/.claude`
idéntico en todas las máquinas. Hoy está afinado para Claude Code en VS Code sobre Windows;
las ideas no dependen de la herramienta.

## Por qué

Este kit nació de usar Claude Code todos los días en tres lugares muy distintos: mis propios
repos, un trabajo de datos en el sector público y contratos de consultoría. Los mismos
problemas aparecían en los tres. Las sesiones gastaban el modelo más caro en trabajo que uno
chico podía hacer, así que empecé a enrutar cada tarea por carril al modelo más barato que la
resuelve. Una sesión que lo hace todo sola pierde el hilo, así que los subagentes leen y
escriben lo mecánico y solo vuelve el resumen. Un modelo que revisa su propio código lo
aprueba, así que la puerta de revisión exige que el revisor nunca sea más débil que el autor.
Lo que de verdad pasó en una sesión desaparecía cuando expiraba el transcript, así que los
hooks lo registran. Y me enteraba tarde de que el contexto era enorme, la caché estaba fría
o el handoff estaba viejo, así que la barra de estado muestra todo eso en vivo en la
terminal: contexto, estado de la caché, cuota del plan, una estimación de costo, el estado de
git y si `HANDOFF.md` todavía describe la realidad. Está hecho para Claude Code en VS Code
hoy; las ideas se portan a Codex CLI y Gemini CLI y ese port está en la hoja de ruta. Lo
comparto para aprender: cada regla apunta al paper o a la medición que la motivó, y espero
que esas referencias cambien conforme cambie la evidencia.

## Qué contiene

`stable` = se usa a diario y tiene tests · `beta` = se usa, sin tests · `experimental` = solo
está la especificación.

| Pieza | Propósito | Madurez |
|---|---|---|
| `home/.claude/statusline.sh` | Barra de estado de dos líneas | `stable` |
| `home/.claude/rules/thresholds.json` | Cada umbral al que reacciona el kit | `stable` |
| 5 hooks (aviso de deriva, borrador pre-compact, log de fallas, log de eventos, reanclaje post-compact) | Registro y guardarraíles del ciclo de vida de la sesión | `stable` |
| 6 agentes (`mecanico`, `operario`, `redactor`, `investigador`, `profundo`, `reviewer`) | Carriles de modelo/esfuerzo para trabajo delegado | `stable` — son prompts, sin suite de tests; se mantienen `stable` porque corren a diario |
| Skills `kickoff`, `spec`, `route`, `handoff`, `xreview`, `manual`, `ahora`, `kit-update` | Ciclo de vida de la sesión | `beta` — se usan, `/ahora` probado en vivo, sin suite |
| Skills `tercerizar`, `visor` | Traspaso a un agente externo · visor de sesiones | `beta` |
| `home/.claude/modules/enjambre/` | Opcional: guarda de ssh + regla para un equipo de varias máquinas; solo se instala con `--with enjambre` | `beta` — 23 tests, nuevo el 2026-10-15 |
| `sync-to-home.sh`, `sync-from-home.sh`, `mirror-lib.sh`, `kit-update.sh`, `verify.sh` | El espejo | `stable` — corre en cada sesión en dos máquinas |
| `harvest.py`, `partidas.py` | Métricas durables desde los transcripts; las sesiones como partidas (vista semanal, jugadas) — [`docs/harvest.es.md`](docs/harvest.es.md) | `beta` — 64 tests con transcripts sintéticos |
| `bitacora.py` | En qué quedó cada proyecto: git, HANDOFF, último prompt, enlaces ([spec](docs/bitacora-spec.es.md)) | `beta` — v1, solo local, 29 tests |
| `.githooks/pre-push`, `tools/install-hooks.sh` | Un `verify.sh` en rojo niega el push | `beta` — 5 tests, nuevo el 2026-10-15 |
| `templates/` | Contratos de SPEC, TASK, AGENTS, REVIEW | `beta` — los usan `/tercerizar` y `/spec` |
| `home/.claude/MANUAL.md` | El porqué detrás de cada regla (español) | `stable` — `verify.sh` audita sus líneas `Fuente:` |

## La barra de estado, explicada

![Mapa de la barra de estado](docs/img/statusline-map.png)

**Un commit por delante del remoto y el HANDOFF está fresco: la pista dice `↑1 sin push → git push`.**
![Un commit por delante, HANDOFF fresco](docs/img/statusline-fable-push-hint.png)

**Una sesión Sonnet en esfuerzo medio con un subagente `redactor` corriendo; caché tibia al 97 %, TTL 59 min.** Las corridas desatendidas usan bypass con un prompt acotado, un hard stop y las compuertas del revisor — ver Roadmap → UNATTENDED. Esta captura muestra ese modo, no el modo por defecto.
![Sesión Sonnet con subagente redactor](docs/img/statusline-sonnet-subagent.png)

**`⚠HANDOFF 0h ·1f`: un archivo modificado es más nuevo que el handoff, así que el handoff ya no describe el árbol.**
![HANDOFF desactualizado por un archivo](docs/img/statusline-fable-dirty-handoff.png)

**La barra renderizada desde fixtures: caché tibia → enfriándose → fría → cerca del auto-compact → HANDOFF desactualizado.** Se regenera con `docs/tapes/render-states.sh`; la fuente que incorpora no tiene los glifos `⎇`/`❄`, así que aquí salen como un cuadro y en las capturas reales de arriba, como son.
![Estados de la barra de estado](docs/img/statusline-states.gif)


**Pruébala en vivo: [kit.ichisieben.dev](https://kit.ichisieben.dev/)**: la barra reaccionando a controles (contexto, caché, cuota, git, HANDOFF, modelo). Cada estado es la salida real de `statusline.sh`, pre-renderizada por `tools/render-grid.sh`; `verify.sh` falla si la barra cambia y la demo no se regenera.

¿Primera vez con la barra? Empieza por la lección [`docs/leccion-01-lee-tu-barra.md`](docs/leccion-01-lee-tu-barra.md): los 18 sectores por grupos, con [un diagrama](docs/img/statusline-sectores.svg) y una autoevaluación.

Glosario completo de símbolos en [`docs/statusline.es.md`](docs/statusline.es.md); el diseño,
los cambios de payload, el costo medido y los tests en
[`docs/statusline-internals.md`](docs/statusline-internals.md) (en inglés).

## Instalación

Requisitos: bash (Git Bash en Windows — así se construyó y se corre), `jq`, `git`. Python 3
solo si usas `harvest.py` o `visor.py`.

```bash
git clone https://github.com/IchiSieben/claude-kit
cd claude-kit
bash sync-to-home.sh   # fusiona solo las claves portables de settings.json en ~/.claude,
                        # respalda lo que reemplaza, nunca borra
bash verify.sh         # verifica que el espejo llegó y corre todas las suites de tests
```

Reinicia Claude Code — `CLAUDE.md`, `settings.json` y las skills se cargan al arrancar el
proceso, así que nada de esto surte efecto a mitad de sesión. Actualiza después con
`bash kit-update.sh` (hace pull, espeja, verifica y recuerda reiniciar).

Lo que NO toca: plugins, marketplaces, tema, notificaciones, `model` y `modelSettings` — eso
es local a cada máquina por diseño, para que una sincronización nunca pise un override de
modelo o esfuerzo propio de esa máquina.

El kit trae un `CLAUDE.md` que es el del propio autor. Bifúrcalo — está pensado para editarse
— y se mantiene bajo 70 líneas a propósito: ese archivo se relee en cada sesión, así que su
largo es un presupuesto de contexto, no una preferencia de estilo.

### Tres guardas, y por qué

Cada una está aquí porque su ausencia costó algo real el 2026-10-15.

- **Un hook `pre-push` que corre `bash verify.sh`** (`bash tools/install-hooks.sh [repo]`,
  sirve también para tus repos). Un HANDOFF que dice «hecho» con verify en rojo es peor que no
  tener HANDOFF. Con el hook, un verify en rojo niega el push; ya no depende de acordarse.
  `tests/prepush_test.sh` lo prueba en un repo desechable.
- **`.gitattributes`: LF por defecto y cada binario con nombre.** `text=auto` adivina. Una
  adivinanza mala, sumada a un `sed -i` que en Windows se come cada `\r`, dejó dos videos
  publicados un byte más cortos. Nadie lo vio hasta que falló una comprobación de hash.
- **`set -euo pipefail` en toda cadena que termina en push.** Sin `-e`, la cadena sigue después
  de un paso fallido. Sin `pipefail`, una tubería solo informa el estado de su último comando: la
  auditoría de fugas de la exportación decía «limpio» con un secreto plantado dentro del kit.
  `verify.sh` falla si un script o un paso de workflow que hace push no lo lleva.

## Si tienes más de una máquina: enjambre

[enjambre](https://github.com/IchiSieben/enjambre) es el proyecto hermano: convierte tus otras
máquinas en nodos de trabajo para todo lo que no necesita pantalla (tests, builds, renders,
corridas largas de `claude -p`). Un trabajo es un `TASK-*.md`; enjambre lo enruta, lo corre en
un worktree limpio en el nodo y te devuelve la rama. Lo que comparten vive en este kit como un
módulo opcional:

```bash
bash sync-to-home.sh --with enjambre
```

- **Un hook que bloquea un `ssh <nodo>` a pelo** hacia uno de tus nodos fuera de los repos de
  enjambre, para que toda delegación pase por su cola y su registro. Los nodos salen de tu
  propio `nodes.toml` (o de `ENJAMBRE_GUARD_HOSTS`); `ENJAMBRE_RAW_SSH=1` lo salta una vez y
  queda anotado.
- **La regla** que el modelo lee en cada sesión: delegar por enjambre, nunca a mano.
- **El bloque `enj` de la barra** (`enj ⬡2/2 ⚙1 ≈$17 hoy`: nodos vivos, trabajos corriendo,
  consumo del día sumando todas las máquinas) ya está en `statusline.sh` y queda en blanco si
  no hay enjambre.

Sin la bandera no se instala nada. Detalle: [`home/.claude/modules/enjambre/README.md`](home/.claude/modules/enjambre/README.md).
Este mismo repo se delega así: `AGENTS.md` nombra el único comando que un nodo puede correr, y el
video de la barra de más abajo lo graba la Mac con `TASK-kit-media.md`.

## Cómo lo uso en un día

**Kickoff.** Cada sesión arranca con [`/kickoff`](docs/routing.es.md): lee `HANDOFF.md`,
`SPEC.md`, el estado de git y la última corrida de tests, y luego propone el siguiente paso y
qué modelo/esfuerzo gastar en él.

**Spec.** Antes de tocar una feature de varios archivos corro [`/spec`](docs/routing.es.md)
para entrevistarme a mí mismo y escribir `SPEC.md` — entradas, salidas, invariantes, fuera de
alcance — así construyo contra un contrato y no contra una intuición.

**Route.** Para cualquier cosa más chica que una spec completa, [`/route`](docs/routing.es.md)
recomienda el carril (`mecanico`, `operario`, `redactor`, `investigador`, `profundo`) y el modo
de ejecución (sesión principal, subagente, worktree, background) antes de gastar el primer
token.

**Qué modelo, desde datos.** `/route` nunca nombra un modelo de memoria. Lee
`home/.claude/rules/models.json` (los hechos: ids, contexto, precios, esfuerzo por defecto; lo
regenera `python tools/model-intel.py` desde la documentación pública de Anthropic) y
`home/.claude/rules/routing.json` (el criterio: carril → familia de modelo + esfuerzo + porqué).
Para cambiar el modelo de un carril, edita `routing.json` y corre `bash tests/route_test.sh`;
cuando cambia el catálogo, corre `model-intel.py` y revisa los carriles. Detalle en
[`docs/routing.es.md`](docs/routing.es.md).

**Construir con subagentes.** La sesión principal decide el qué y el cómo; los seis agentes de
[`docs/routing.es.md`](docs/routing.es.md) hacen la lectura y la escritura mecánica, y solo su
resumen vuelve a la sesión que está pagando el contexto.

**Puerta de revisión.** [`/xreview`](docs/reviewer.es.md) arma el paquete del diff, la spec y
la rúbrica para una revisión cruzada entre modelos, o lanza al agente `reviewer` — nunca el
mismo modelo que escribió el código, porque la regla es revisor ≥ autor, y cambiar el modelo de
la sesión a mitad de tarea solo mata la caché de prompt.

**Handoff.** Antes de compactar o cerrar, [`/handoff`](docs/handoff.es.md) escribe
`HANDOFF.md`: objetivo, estado, decisiones, qué falló, próximos pasos — para que la siguiente
sesión (mía o una nueva) no vuelva a explorar lo que esta ya encontró. Ver
[`docs/context.es.md`](docs/context.es.md) para las bandas de tokens que disparan esto y
[`docs/thresholds.es.md`](docs/thresholds.es.md) para cada número detrás de las pistas de la
barra de estado. [`docs/hooks.es.md`](docs/hooks.es.md) y
[`docs/manual-and-now.es.md`](docs/manual-and-now.es.md) cubren el registro de fondo y los
comandos `/manual` y `/ahora` que lo muestran.

## Referencias

Las reglas que citan evidencia se contrastan con los papers reales en
[`docs/references.es.md`](docs/references.es.md); las citas que no se pudieron resolver figuran
ahí como no verificadas, sin maquillarlas. La compuerta del revisor ("el revisor nunca más
débil que el autor") se apoya en Panickssery et al., "LLM Evaluators Recognize and Favor Their
Own Generations," NeurIPS 2024 ([arXiv:2404.13076](https://arxiv.org/abs/2404.13076)); los
candidatos encontrados para las citas que no se pudieron verificar están en
[`docs/references-candidates.es.md`](docs/references-candidates.es.md). Se espera que las
referencias cambien conforme cambie la evidencia — propone o cuestiona una con
[`.github/ISSUE_TEMPLATE/reference.md`](.github/ISSUE_TEMPLATE/reference.md).

## Hoja de ruta

- Barra de estado: la meta de 200 ms queda por debajo del piso de Windows (~225 ms: bash más un
  jq), así que se corrigió en vez de cumplirse. 2026-10-15: de 8 a 6 procesos por render completo.
  Falta la columna de la Mac en `docs/statusline-internals.md` (lane `bench`, 2026-10-15). El
  indicador de `permission_mode` vuelve si el payload lo trae de nuevo.
- Alertas: por ahora ninguna más allá de la pista de la barra y el aviso rojo de deriva en
  `SessionStart`.
- `/ahora` híbrido — git en vivo más deriva, en vez de solo un snapshot.
- Bitácora v2: publicar un snapshot en vez de una página local (la v1 y el reporte semanal,
  `partidas.py`, salieron el 2026-10-15).
- `/tercerizar` v2; el esquema de un registro de proyectos podría publicarse aunque el
  registro en sí se mantenga privado.
- Ports: Codex CLI, Gemini CLI — sin empezar.
- Orquestación en paralelo — referencia propia "JEP": `[owner: specify]`.
- Todavía no existe un presupuesto de gasto por escrito — los umbrales miden cuota, no dinero.
- El formato del manual, y la forma en que se produce y se lee, es una brecha conocida: es una
  primera versión. Falta mejorar la legibilidad y el proceso de producción.
- Una demo interactiva o en video de la barra reaccionando en vivo — caché enfriándose,
  compactación, handoff. En curso: una grabación de terminal desde fixtures
  (`docs/tapes/media.sh`, corre en la Mac).
- Una línea `UNATTENDED:` de pre-aprobación, para que una sesión pueda aceptar un alcance sin
  supervisión ya aprobado por el autor, sin tener que detenerse a preguntar.

## Licencia

[Apache-2.0](LICENSE).

## Autor

Yoichi Palacios Tanaka (IchiSieben) · [ichisieben.dev](https://ichisieben.dev)

Data engineer / developer, Lima, Perú — GitHub [IchiSieben](https://github.com/IchiSieben). Ver
[`CITATION.cff`](CITATION.cff) si construyes sobre esto.
