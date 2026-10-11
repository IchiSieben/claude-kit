# Arquitectura de Claude Kit: notas de investigación

Fecha: 2026-10-10. Fuente: el código de este repo (scripts de espejo, hooks, barra de estado, pruebas). Lo que no está en el código queda como "por confirmar" y no se dibuja.

## Las 9 preguntas

1. **Actores.** Una persona que trabaja con Claude Code en dos máquinas (PC Windows y Mac mini). Sistemas externos: GitHub (origen del repo público) y la propia sesión de Claude Code, que arranca los hooks y la barra de estado. No hay usuarios finales ni roles.
2. **Contenedores.** No hay servicios desplegables. Piezas que corren por separado:
   - clon del repo (`home/.claude/` es la fuente de verdad de lo que viaja);
   - scripts de espejo (bash): `sync-to-home.sh`, `sync-from-home.sh`, `mirror-lib.sh`, `kit-update.sh`;
   - `verify.sh` y las pruebas (`tests/statusline_test.sh`, `tests/hooks_test.sh`);
   - el directorio de configuración del usuario (`~/.claude`) en cada máquina;
   - la sesión de Claude Code (externa);
   - cinco hooks (bash + jq), la barra de estado (`statusline.sh`, bash >= 4.2), `rules/thresholds.json`;
   - registros y estado locales (`~/.claude/logs`, `~/.claude/state`, borradores en `docs/handoffs/`);
   - herramientas de archivo `harvest.py` y `visor.py` (Python): no se dibujan, ver "No dibujado".
3. **Llamadas reales.** Tabla más abajo, con archivo y función de cada una.
4. **Flujos.** Cuatro: instalar o actualizar el kit en una máquina; una sesión lee las reglas y un hook actúa; la barra de estado se repinta; publicar la versión pública filtrada.
5. **Componentes internos del núcleo.** No aplica (sin API ni lógica de negocio con puertos y adaptadores).
6. **Datos.** No hay base de datos. Almacenamiento en archivos: `events.jsonl` y `tool-failures.jsonl` (una línea JSON por evento), un snapshot JSON por sesión en el directorio de estado (la barra lo escribe y `/ahora` lo lee; `log-event.sh` barre los de más de 24 h al cerrar sesión), borradores `docs/handoffs/<fecha>-draft.md` (ignorados por git). Vista de datos omitida.
7. **Despliegue.** Cada máquina: `git pull --ff-only`, `sync-to-home.sh`, `verify.sh`, reiniciar Claude Code (`kit-update.sh`). No hay servidor. Al escalar a más máquinas el mismo flujo se repite; no hay inventario central (por confirmar si se quiere uno).
8. **Historias de usuario.** No aplica (herramienta personal).
9. **Decisiones.** No existe `docs/DECISIONES.md`; las decisiones de la página están inferidas de los comentarios del código y marcadas como inferidas.

## Tabla de llamadas (evidencia)

| Arista | De, a | Qué viaja | Evidencia |
|---|---|---|---|
| e1 | fuente privada, GitHub | árbol público filtrado | `docs/img/README.md` (menciona `tools/build-kit.sh`), `docs/statusline-internals.md` (repo privado de origen). El script no está en este repo. |
| e2 | GitHub, clon | `git pull --ff-only` | `kit-update.sh` |
| e3 | clon, scripts de espejo | lista de archivos permitidos | `mirror-lib.sh: mirror_list` |
| e4 | scripts, directorio de usuario | copia con LF, respaldo, fusión de claves portables de `settings.json` | `sync-to-home.sh` (bucle principal, `jq -s`, `backup`, `copy_lf`) |
| e5 | directorio de usuario, clon | copia inversa; informa archivos sobrantes sin borrar | `sync-from-home.sh` (`STALE`) |
| e6 | verify, directorio de usuario | comparación de deriva | `verify.sh` (Fase E, `same_portable`, `same_lf`) |
| e7 | verify, pruebas | ejecuta las dos suites | `verify.sh` (`bash tests/statusline_test.sh`, `bash tests/hooks_test.sh`) |
| e8 | sesión, directorio de usuario | carga CLAUDE.md, reglas, agentes, skills, settings al arrancar | `kit-update.sh` (aviso de reinicio), `docs/hooks.md` |
| e9 | sesión, hooks | payload JSON por stdin en cada evento | `home/.claude/settings.json` (bloque `hooks`), `hooks/log-event.sh` |
| e10 | sesión, barra | payload JSON por stdin | `settings.json` (`statusLine.command`), `statusline.sh` |
| e11 | barra, umbrales | lectura de `rules/thresholds.json` | `statusline.sh` (`TH_FILE`, `th_load`) |
| e12 | hooks, registros | líneas JSON, borradores | `log-event.sh`, `log-tool-failure.sh`, `precompact-draft.sh` |
| e13 | barra, estado | snapshot JSON por sesión | `statusline.sh` (bloque con `CC_STATE_DIR`) |
| e14 | hooks, barra | `statusline.sh --drift <dir>` | `session-drift-warn.sh`, `precompact-draft.sh` |
| e15 | pruebas, hooks | payload sintético con HOME falso | `tests/hooks_test.sh` |
| e16 | hooks, umbrales | los dos umbrales de deriva roja | `session-drift-warn.sh` (`jq` sobre `thresholds.json`) |
| e17 | barra, sesión | texto de la barra por stdout | `statusline.sh` |

## No dibujado / por confirmar

- Interior de `tools/build-kit.sh` (lo que filtra y cómo): el script no está en este repo, solo se menciona. Se dibuja una sola arista, sin detalle.
- `.gitleaks.toml`: hay configuración de gitleaks, pero no hay workflow ni hook en el repo que lo ejecute. Por confirmar dónde corre.
- `harvest.py` y `visor.py`: `sync-to-home.sh` copia `visor.py` a una carpeta de archivo del usuario; `harvest.py` lee transcripciones locales. Son herramientas aparte del flujo principal; no se dibujan.
- La barra también lee un campo de cuota que llega en el payload; no se dibuja.
- `.github/ISSUE_TEMPLATE/reference.md`: solo una plantilla de issue.

## Privacidad

El repo ya es público y los scripts usan `$HOME`; no hay rutas personales en el código revisado. El archivo `LICENSE`, `CITATION.cff` y los README llevan el nombre del autor: no se copia nada de eso a la página.
