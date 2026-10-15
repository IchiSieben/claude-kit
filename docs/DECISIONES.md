# Decisiones tomadas sin el owner

Formato: fecha · tarea · qué se eligió · por qué · qué se descartó · cómo revertirlo.

## 2026-10-15 · V1 ecosistema

- **Dónde se edita el código.** Elegido: barra, umbrales, tests y hooks se editan en
  el repo privado de origen y se exportan con `tools/build-kit.sh`; documentación solo en el público.
  Por qué: `~/.claude/statusline.sh` es idéntico al del repo privado; un cambio solo en el
  público no llegaría a la barra real y el próximo export lo pisaría. Descartado: trabajar en
  el público directo (la salida del §3 es para un `build-kit.sh` roto, y no lo está).
  Revertir: no aplica; los commits del repo privado quedan en su rama principal.
- **`/route` no se exporta.** Elegido: tras cada export se devuelve
  `home/.claude/skills/route/SKILL.md` a la versión pública. Por qué: la del repo privado lee
  `~/.claude/rules/models.json` y `routing.json`, que no están en la allowlist de PUBLISH.md:
  el kit publicaría un skill con una referencia colgante. Descartado: añadir esos dos JSON a la
  allowlist (los genera `model-intel.py`, que tampoco se publica; quedarían viejos).
  Revertir / decidir: añadir `rules/models.json` + `rules/routing.json` (+ `tools/model-intel.py`)
  a `AS_IS` en `build-kit.sh` y dejar de restaurar el archivo. **Pregunta para el owner.**
