---
lesson:
  route: code-like-me
  order: 5
  level: 2
---

# Hooks

Cinco scripts en `home/.claude/hooks/`, conectados en
`home/.claude/settings.json`. Todo hook sale siempre con código 0 — un hook
nunca debe ser la razón de que fallen la sesión, una compactación o la
herramienta que observa.

## Tabla

| Evento · matcher | Script | Escribe en |
|---|---|---|
| `SessionStart` (`compact`) | `compact-reinject.sh` | solo stdout (sin archivo) |
| `SessionStart` (`startup\|resume\|clear\|compact`) | `log-event.sh` | `~/.claude/logs/events.jsonl` |
| `SessionStart` (`startup\|resume\|clear`) | `session-drift-warn.sh` | solo stdout (sin archivo) |
| `PreCompact` | `log-event.sh` | `~/.claude/logs/events.jsonl` |
| `PreCompact` | `precompact-draft.sh` | `docs/handoffs/<fecha>-draft.md` |
| `PostCompact` | `log-event.sh` | `~/.claude/logs/events.jsonl` |
| `SubagentStop` | `log-event.sh` | `~/.claude/logs/events.jsonl` |
| `SessionEnd` | `log-event.sh` | `~/.claude/logs/events.jsonl` + barre `~/.claude/state/` |
| `PostToolUseFailure` (`Bash`) | `log-tool-failure.sh` | `~/.claude/logs/tool-failures.jsonl` |

`log-event.sh` es un único script reutilizado en seis combinaciones de
evento/matcher; lee `hook_event_name` de su propio payload para decidir qué
más hacer.

## Hechos del contrato

- **El stdout de `SessionStart` se agrega al contexto de la sesión.** Es la
  única razón por la que `session-drift-warn.sh` llega al usuario. Como
  cuesta tokens en cada arranque, no imprime nada salvo que la deriva del
  HANDOFF esté en banda roja — un aviso que aparece en cada sesión es un
  aviso que nadie lee al tercer día.
- **El stdout de `PreCompact` va solo al log de debug** — no se muestra, no
  se inyecta. Por eso `precompact-draft.sh` escribe el aviso de "todavía te
  falta la parte de criterio" *adentro del archivo del draft*, no por
  stdout: por esa vía nunca llegaría al usuario.
- **El código de salida 2 en `PreCompact` bloquea la compactación.** Todos
  los hooks de este kit salen con 0 exactamente por eso: un draft o una
  línea de log que no se pueda escribir nunca debe costarle al usuario una
  compactación.
- **Payload de `PostToolUseFailure` (`Bash`)**, capturado de una corrida real:
  `session_id`, `transcript_path`, `cwd`, `scratchpad_dir`, `prompt_id`,
  `permission_mode`, `effort.level`, `hook_event_name`, `tool_name`,
  `tool_input.{command,description}`, `tool_use_id`, `error`,
  `is_interrupt`, `duration_ms`. `PostToolUse` dispara solo en éxito; los
  fallos llegan por este evento separado. `tool_response` es `null` en el
  fallo, así que no hay código de salida estructurado — el script se queda
  con la primera línea de `error` (`"Exit code N"`) en lugar de inventar uno.

## Redacción antes de tocar disco

`log-tool-failure.sh` redacta el comando capturado *antes* de escribirlo, no
después — truncar solo no protege un secreto que empieza en el carácter 10.
Patrones redactados (ver el `gsub` exacto en el script):

- Claves de proveedor: `sk-`, `ghp_`, `gho_`, `ghs_`, `github_pat_`,
  `xox[baprs]-`, `AKIA`, `ASIA`.
- `Bearer <token>` / `Basic <token>` / `token <valor>` suelto, tratado como
  regla propia antes de la genérica, para que la palabra del esquema de auth
  no se confunda con el secreto.
- Pares `clave=valor` / `clave: valor` cuya clave parece `token`, `password`,
  `passwd`, `secret`, `api[-_]?key` o `authorization`.
- Flags `--pass`, `--password`, `--token`, `--secret`.
- El comando se trunca luego a 160 caracteres.

## `is_interrupt` no se registra

`log-tool-failure.sh` descarta cualquier payload con `is_interrupt` en
`true` antes de escribir. Esa marca significa que el usuario interrumpió el
comando — no es un comando fallido y no debe registrarse como lección.

## Barrido de 24h en `SessionEnd`

`log-event.sh`, cuando el evento es `SessionEnd`, borra los archivos de
`~/.claude/state/` (o `$CC_STATE_DIR`) con más de 1440 minutos (24h). La
barra de estado escribe un snapshot chico por sesión ahí y nada lo borraba
antes. El corte de 24h existe porque un snapshot solo le sirve a `/ahora`
mientras esa sesión sigue viva, y el de una sesión activa se reescribe en
cada render — así que un archivo sin tocar en un día pertenece a una ventana
que ya terminó.

## Re-anclaje después de compactar

`compact-reinject.sh` corre en `SessionStart` con matcher `compact`, y su
stdout sí se inyecta en el contexto recién compactado (esa ruta sí se
muestra). Imprime:

- `=== POST-COMPACT RE-ANCHOR ===`
- las primeras 80 líneas de `HANDOFF.md` si existe, o un aviso de que falta
  y que conviene correr `/handoff` antes de seguir con trabajo largo
- `git log --oneline -5`
- `git status --short` (primeras 15 líneas)
- una regla de cierre: releer el paso actual en `HANDOFF.md` antes de actuar,
  no repetir pasos ya completados

## Qué prueba `tests/hooks_test.sh`

Cubre los cuatro scripts distintos — `log-tool-failure.sh`,
`precompact-draft.sh`, `session-drift-warn.sh` y `log-event.sh` — contra
payloads de stdin sintéticos con la forma de una corrida real 2.1.276,
usando un repo git descartable y un `HOME` falso ubicado *fuera* de ese
repo. Que `HOME` quede afuera importa: un archivo de log creado dentro del
repo contaría como archivo sucio más nuevo que `HANDOFF.md` y ensuciaría los
contadores de deriva bajo prueba.
