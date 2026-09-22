# SPEC — Bitácora (v1 del claude-kit)   ·  12 sep 2026

## Goal
Una página local que responda, de un vistazo, **"¿en qué quedó cada proyecto y dónde sigo?"**
para tus ~40 repos. No es un monitor en vivo ni un panel de gasto: es el índice del
portafolio, con el estado real de cada proyecto y un botón a cada sitio donde vive.

## Users and trigger
El dueño del kit, solo. La abre al empezar el día, al retomar un proyecto parado, y antes de decidir
en qué trabajar. Se regenera con un comando (`python bitacora.py`) y se abre en el navegador.

## Inputs
| Fuente | Qué aporta | Nota |
|---|---|---|
| `~/claude-archive/sessions.json` | tokens, modelos, costo y fechas por sesión, por proyecto | lo produce `harvest.py`; sobrevive al barrido de 30 días |
| `~/.claude/history.jsonl` | cada prompt tipeado, con timestamp y ruta del proyecto | **nunca lo borra el barrido**; de aquí sale "el último prompt" |
| `<repo>/HANDOFF.md` | estado declarado: DONE / IN PROGRESS / BLOCKED / next steps | ya existe por el método; si falta, el proyecto aparece marcado "sin handoff" |
| `<repo>/.git` | rama, último commit y fecha, archivos sin commitear, remote | el remote da el link a GitHub |
| `projects.toml` (a mano) | links que no se pueden derivar: URL desplegada, carpeta de Drive, notas | una entrada por proyecto, opcional |

## Outputs
- `~/claude-archive/bitacora.html` — autocontenido, un solo archivo, abre offline.
- `~/claude-archive/bitacora.json` — los mismos datos, para reutilizar después (v2 Hostinger, otro LLM).

## Contenido de cada tarjeta de proyecto
Nombre · estado (activo / parado / archivado, derivado de la última actividad) · una línea del
HANDOFF ("IN PROGRESS: …") · último commit y si hay cambios sin commitear · último prompt que
escribí y cuándo · tokens y costo de los últimos 30 días · botones: carpeta local, GitHub, sitio
desplegado, Drive.

Orden por defecto: última actividad, descendente. Filtro: activos / parados / todos.

## Invariants (no se rompen nunca)
1. **Solo lectura.** No escribe ni modifica nada dentro de los repos ni de `~/.claude`.
2. **Solo metadatos.** No copia contenido de transcripts. El texto de prompts de `history.jsonl`
   se muestra pero no se exporta a `bitacora.json` salvo que se pase `--include-prompts`.
3. **Sin red.** La v1 no sube nada a ninguna parte. Publicar es un paso aparte y explícito.
4. **Degrada, no falla.** Un repo sin HANDOFF.md, sin git o sin entrada en `projects.toml`
   aparece igual, con los campos que falten marcados; nunca aborta la generación.
5. Si `sessions.json` no existe, la página se genera igual sin la columna de tokens.

## Out of scope (v1)
Sesiones en vivo. Gasto agregado por semana. Subida a Hostinger. Sugerencias de modelo.
Cualquier cosa que escriba en los repos. Todo eso es v2+ y se decide con datos de la v1.

## Architecture (tres capas)
- **Capa 1, determinista (todo el trabajo):** `harvest.py` ya existe; `bitacora.py` lee las
  cinco fuentes, arma un dict por proyecto y renderiza el HTML con una plantilla. Python puro,
  stdlib, sin dependencias. Testeable con un repo de prueba.
- **Capa 2, instrucciones:** una skill `/bitacora` que corre el script y resume los 3 proyectos
  que más piden atención.
- **Capa 3, el modelo:** no participa en la generación. Solo lee el resultado cuando le pides
  "¿qué retomo hoy?".

## Acceptance checks
- [ ] `python bitacora.py --dry-run` → lista los proyectos detectados y de qué fuente sacó cada campo, sin escribir
- [ ] `python bitacora.py` → genera `bitacora.html`; abre en el navegador sin errores de consola
- [ ] Un repo sin `HANDOFF.md` aparece en la página marcado "sin handoff"
- [ ] Un repo sin `.git` aparece sin romper la generación
- [ ] `grep -c "sk-\|password\|token=" bitacora.json` → 0
- [ ] Correr dos veces seguidas produce el mismo HTML salvo timestamps
- [ ] `python -m pytest tests/ -q` → verde

## Decisiones ya tomadas
- Local primero; Hostinger es v2 y será *subir un snapshot*, no un colector remoto:
  el hosting es compartido, no admite procesos persistentes.
- Solo metadatos en el archivo histórico.
- La bitácora **lee HANDOFF.md**, así que el método de trabajo alimenta al dashboard.
  Cada `/handoff` que corras mejora la bitácora sin trabajo extra.

## Open questions (resolver en la entrevista, no ahora)
- ¿Dónde están todos los repos? ¿Una carpeta raíz o varias?
- ¿Qué cuenta como "parado": 14 días sin commits, sin sesión, o sin prompt?
- ¿`projects.toml` a mano, o derivar el link desplegado del remote de git cuando exista?
