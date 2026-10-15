# HANDOFF — claude-kit · sesión V1 ecosistema (2026-10-15)

Prompt: `../docs/PROMPT-ecosistema-claude-code.md` §3 (V1). Modo dormido: sin preguntas en chat.

## Lo entendido y el plan (10 líneas)

1. El público es un espejo filtrado de un repo privado de origen; `~/.claude/statusline.sh` es byte a byte el del repo privado, no el del público.
2. `build-kit.sh` funciona, pero el repo privado avanzó desde el último export (locale C, HANDOFF con hora, segmento `enj`, umbrales visor-*, /route con models.json).
3. Por eso: el CÓDIGO (barra, umbrales, tests, hooks) se edita en el repo privado y se exporta; los DOCS (README, docs/, lección, ficha) se editan en el público.
4. Commit 0: export de sincronía, devolviendo `skills/route/SKILL.md` a la versión pública (lee `rules/models.json`, que no está en la allowlist).
5. Ítem 1: re-captura del payload 2.1.300 → estado de caché `⚡ caliente · Nm` / `⚠ enfriando · Nm` / `❄ fría`, `hit N%` aparte, umbral `cache-cooling` en thresholds.json, fixtures y GIF.
6. Push a main temprano (pre-aprobado con verify.sh verde) para que la Mac clone el árbol real.
7. Ítem 4: `AGENTS.md` con `tests-cmd` + `TASK-kit-media.md`, lanzado a la Mac por enjambre.
8. Ítem 3: módulo `home/.claude/modules/enjambre/` (hook guard + párrafo + README), `sync-to-home.sh --with enjambre`; PUBLISH.md/build-kit dejan de vetarlo.
9. Ítem 2: lección `docs/leccion-01-lee-tu-barra.{md,en.md}` + SVG de sectores + frontmatter `lesson:` en docs bilingües.
10. Ítem 5: `docs/FICHA-LANDING.md`, arquitectura con flujo "módulo enjambre", `FICHA-READY: <commit>`. Cierre con DECISIONES y NOTES.

## Estado

- **Sync (commit 0)** hecho: export del repo privado (locale C, HANDOFF con hora, segmento `enj`,
  bandas visor-*, /handoff y /spec), `/route` retenido (ver DECISIONES).
- **Ítem 1 hecho**: payload re-capturado (2.1.292–2.1.300, 24 renders, forma sin cambios); segmento
  de caché `⚡ caliente · 42m` / `⚡ enfriando · 4m` / `❄ fría · próximo turno reescribe` en la
  línea 1, `hit N%` en la línea 2 solo bajo `cache-hit-ok`; `cache-cooling` + `labels` en
  thresholds.json; 3 fixtures nuevas; goldens re-bendecidos. GIF/PNGs → trabajo de la Mac.
  Render budget: medido con la máquina cargada, sin cambio atribuible (DECISIONES).
- **Ítem 4 preparado**: `AGENTS.md` (`tests-cmd: bash tools/lane.sh`), `docs/tapes/media.sh`
  (VHS + ffmpeg + freeze), `TASK-kit-media.md`.
- Pendiente: lanzar ítem 4, ítems 3, 2, 5, cierre.
- `~/.claude` NO se re-sincronizó (4 barras vivas): cuando quieras la barra nueva,
  en el repo privado de origen corre `bash sync-to-home.sh`.
