# Ficha del Landing — claude-kit

Contenido exacto para `Landing/src/content/projects/es/claude-kit.md` y
`Landing/src/content/projects/en/claude-kit.md`. Los campos `family`, `siblings` y `academyRoute`
existen en el esquema de la rama `ecosistema/2026-10-15` del Landing, no en `main`.

Cifras verificadas el 2026-10-15 en Windows + Git Bash, en el commit que escribe `FICHA-READY`
en `HANDOFF.md`:

| Cifra | Valor | Cómo se obtiene |
|---|---|---|
| Pruebas en verde | 140 | `statusline_test.sh` 67 + `hooks_test.sh` 38 + `enjambre_module_test.sh` 23 + `route_test.sh` 12 |
| Render completo de la barra | ~476 ms | `docs/statusline-internals.md` § Cost (medido en reposo, 2026-09-22) |
| Hooks | 5 (+1 opcional) | `home/.claude/hooks/` · el módulo enjambre añade `enjambre-ssh-guard.sh` |
| Skills | 10 | `home/.claude/skills/` |
| Agentes | 6 | `home/.claude/agents/` |

El prompt pedía `"Open source · 79 tests"` (la cifra del 2026-09-22); el owner aprobó usar la
cifra del día. El 2026-10-15 por la tarde son 140: se sumó `route_test.sh` (ver `docs/DECISIONES.md`).

`demoUrl` es el simulador de la barra, publicado en https://kit.ichisieben.dev/ (docroot `kit-app`).

## `media` — listo; pegar cuando el Landing copie los archivos

El esquema rompe el build si `public/media/claude-kit/` no tiene los archivos. **Medios nuevos
desde el 2026-10-15 (V1c):** el clip se grabó de la demo v2 (https://kit.ichisieben.dev/), con el
recorrido de causa → efecto; el póster es el fotograma de 5,6 s (barra en rojo, líneas vivas y
rótulo). Grabado en Windows contra el sitio publicado, porque la lane de la Mac se colgó (ver
`docs/DECISIONES.md`). Los `statusline-*` anteriores quedan en el repo como histórico.

| En este repo | En el Landing | sha256 (12) |
|---|---|---|
| `docs/media/demo-poster.webp` (1280x720, 33 KB) | `public/media/claude-kit/poster.webp` | `85a540975ad2` |
| `docs/media/demo-poster-mobile.webp` (640x360, 9 KB) | `public/media/claude-kit/poster-mobile.webp` | `d0ca6e1d3902` |
| `docs/media/demo-preview.mp4` (H.264, 24 s, 531 KB) | `public/media/claude-kit/preview.mp4` | `6c1df21f849a` |
| `docs/media/demo-preview.webm` (VP9, 24 s, 534 KB) | `public/media/claude-kit/preview.webm` | `e4834da207c3` |

```yaml
media:
  kind: video
  poster: /media/claude-kit/poster.webp
  posterMobile: /media/claude-kit/poster-mobile.webp
  video:
    mp4: /media/claude-kit/preview.mp4
```

## es/claude-kit.md

```markdown
---
title: "Claude Kit"
segment: "agentes-ia"
tech: ["ia-agentes", "automatizacion"]
sector: ["herramientas-dev"]
order: 13
featured: false
status: "live"
maturity: "usable"
statusNote: "Open source · 140 tests"
published: true
since: 2026
date: "2026-10-15"
family: "claude-code-ecosystem"
siblings: ["enjambre", "cert-studio"]
academyRoute: "code-like-me"
summary: "Mi configuración de Claude Code, publicada y saneada: reglas de enrutamiento por carril, seis subagentes, diez skills, cinco hooks y una barra de estado que dice la verdad sobre el contexto, la caché y el HANDOFF. Unos scripts de espejo la dejan idéntica en cada máquina sin borrar nada."
oneLine: "La configuración de Claude Code con la que construí este portafolio: reglas, agentes, hooks y una barra de estado que no miente, igual en cada máquina."
techLine: "Bash · jq · git · Claude Code"
repoUrl: "https://github.com/IchiSieben/claude-kit"
demoUrl: "https://kit.ichisieben.dev/"
skills:
  - "bash"
  - "windows"
  - "git"
  - "llm-agentes"
  - "macos-arm"
applied:
  bash: "La barra de estado, los cinco hooks y los scripts de espejo son bash + jq, con 140 pruebas, entre ellas las que comparan la barra contra salidas guardadas con reloj y ancho fijos."
  windows: "Se usa a diario en Windows con Git Bash; ahí cada proceso lanzado cuesta 50–65 ms, y por eso la barra hace una sola llamada a jq para todos los campos."
  git: "La barra cuenta commits sin push, archivos sucios y si el HANDOFF quedó atrás del árbol; kit-update.sh solo avanza con git pull --ff-only."
  llm-agentes: "Seis subagentes por carril (de haiku a opus) y una regla de revisión: el revisor nunca es más débil que el autor."
  macos-arm: "El mismo ~/.claude corre en una Mac mini con Apple Silicon; el video de la barra se graba ahí, delegado por enjambre."
problem: "Usaba Claude Code todo el día en tres frentes y los mismos problemas aparecían en todos: el modelo más caro haciendo trabajo de uno chico, sesiones que perdían el hilo y descubrir demasiado tarde que el contexto estaba enorme, la caché fría o el traspaso desactualizado."
results:
  - { label: "pruebas automáticas en verde", value: 140, source: "statusline 67 + hooks 38 + módulo enjambre 23 + /route 12, Windows, 2026-10-15" }
  - { label: "render completo de la barra en Windows + Git Bash", value: 476, unit: "ms", source: "docs/statusline-internals.md, 2026-09-22" }
  - { label: "hooks del ciclo de sesión", value: 5, source: "home/.claude/hooks, 2026-10-15" }
  - { label: "skills", value: 10, source: "home/.claude/skills, 2026-10-15" }
  - { label: "subagentes por carril", value: 6, source: "home/.claude/agents, 2026-10-15" }
next:
  - "Bajar el render de la barra o aceptar el presupuesto: 476 ms medidos contra 200 ms de meta; falta medir en la Mac."
  - "Portar las ideas a Codex CLI y Gemini CLI."
  - "Una línea UNATTENDED: para que una sesión acepte un alcance aprobado sin detenerse a preguntar."
---

Un repo es la fuente de verdad de lo que Claude Code lee en cada máquina: `CLAUDE.md`, reglas,
agentes, skills, hooks, la barra de estado y `rules/thresholds.json`, el único lugar con números.
`sync-to-home.sh` lo copia a `~/.claude` con respaldo, fusiona solo las claves portables de
`settings.json` y nunca borra; `verify.sh` comprueba que aterrizó y corre las tres suites.

La barra lee el JSON que Claude Code le pasa en cada turno y lo pinta en dos líneas: contexto en
tokens absolutos, estado de la caché en una palabra (`caliente`, `enfriando`, `fría`) y sus
minutos, cuota del plan, git y la frescura del HANDOFF. Un dato que falta se pinta `⚠`, nunca `0`.
La lección 01 de la ruta *Code like me* la explica sector por sector. El simulador de la barra (el enlace de demo) la
muestra reaccionando a controles: cada estado es la salida real del script, pre-renderizada.

Para quien tiene más de una máquina, el módulo opcional `enjambre` (`--with enjambre`) añade un
hook que bloquea el `ssh` directo a los nodos y obliga a delegar por la cola de enjambre.

Límites: la barra tarda unos 476 ms en Windows, por encima de la meta de 200 ms; el `CLAUDE.md`
del kit son las reglas de su autor y está pensado para editarse. Código bajo Apache-2.0.
```

## en/claude-kit.md

```markdown
---
title: "Claude Kit"
segment: "agentes-ia"
tech: ["ia-agentes", "automatizacion"]
sector: ["herramientas-dev"]
order: 13
featured: false
status: "live"
maturity: "usable"
statusNote: "Open source · 140 tests"
published: true
since: 2026
date: "2026-10-15"
family: "claude-code-ecosystem"
siblings: ["enjambre", "cert-studio"]
academyRoute: "code-like-me"
summary: "My Claude Code setup, published and sanitised: lane-based routing rules, six subagents, ten skills, five hooks and a status line that tells the truth about context, cache and the HANDOFF. Mirror scripts keep it identical on every machine without deleting anything."
oneLine: "The Claude Code setup I built this portfolio with: rules, agents, hooks and a status line that does not lie, the same on every machine."
techLine: "Bash · jq · git · Claude Code"
repoUrl: "https://github.com/IchiSieben/claude-kit"
demoUrl: "https://kit.ichisieben.dev/"
skills:
  - "bash"
  - "windows"
  - "git"
  - "llm-agentes"
  - "macos-arm"
applied:
  bash: "The status line, the five hooks and the mirror scripts are bash + jq, with 140 tests, including suites that compare the bar against saved output at a fixed clock and width."
  windows: "Used daily on Windows with Git Bash, where every spawned process costs 50–65 ms, which is why the bar makes a single jq call for every field."
  git: "The bar counts unpushed commits, dirty files and whether the HANDOFF fell behind the tree; kit-update.sh only moves with git pull --ff-only."
  llm-agentes: "Six subagents by lane (haiku to opus) and one review rule: the reviewer is never weaker than the author."
  macos-arm: "The same ~/.claude runs on an Apple Silicon Mac mini; the status-line video is recorded there, delegated through enjambre."
problem: "I used Claude Code all day on three fronts and the same problems showed up in all of them: the most expensive model doing a small model's job, sessions losing the thread, and finding out too late that context was huge, the cache was cold or the handoff was stale."
results:
  - { label: "automated tests passing", value: 140, source: "statusline 67 + hooks 38 + enjambre module 23 + /route 12, Windows, 2026-10-15" }
  - { label: "full status-line render on Windows + Git Bash", value: 476, unit: "ms", source: "docs/statusline-internals.md, 2026-09-22" }
  - { label: "session lifecycle hooks", value: 5, source: "home/.claude/hooks, 2026-10-15" }
  - { label: "skills", value: 10, source: "home/.claude/skills, 2026-10-15" }
  - { label: "subagents by lane", value: 6, source: "home/.claude/agents, 2026-10-15" }
next:
  - "Cut the bar's render time or accept the budget: 476 ms measured against a 200 ms target; the Mac is not measured yet."
  - "Port the ideas to Codex CLI and Gemini CLI."
  - "An UNATTENDED: line so a session can accept an approved scope without stopping to ask."
---

One repo is the source of truth for what Claude Code reads on every machine: `CLAUDE.md`, rules,
agents, skills, hooks, the status line and `rules/thresholds.json`, the only place with numbers.
`sync-to-home.sh` copies it into `~/.claude` with a backup, merges only the portable
`settings.json` keys and never deletes; `verify.sh` checks it landed and runs the three suites.

The bar reads the JSON Claude Code hands it on every turn and draws two lines: context in absolute
tokens, the cache state in one word (`caliente`, `enfriando`, `fría`) plus its minutes, plan
quota, git and how fresh the HANDOFF is. A missing field is painted `⚠`, never `0`. Lesson 01 of
the *Code like me* route walks through it sector by sector. The status line simulator (the demo link) shows
it reacting to controls: every state is the script's real output, pre-rendered.

For anyone with more than one machine, the optional `enjambre` module (`--with enjambre`) adds a
hook that blocks a raw `ssh` to the nodes and makes every delegation go through enjambre's queue.

Limits: the bar takes about 476 ms on Windows, over the 200 ms target; the kit's `CLAUDE.md` is
its author's own rules and is meant to be edited. Code under Apache-2.0.
```
