# Status line legend

The bar renders two lines from the JSON that Claude Code pipes to the command's stdin on
every render (`home/.claude/statusline.sh`). Numbers never come from the script itself:

> EVERY number this bar reacts to lives in rules/thresholds.json, next to this script.
> None of them is written here: a threshold that exists in two places drifts. If that
> file is missing or unreadable the bar says `⚠ umbrales` and stops colouring and
> hinting — a threshold you cannot read is not the same thing as a threshold that is
> not crossed.

> THE RULE THIS FILE IS BUILT AROUND: a missing or unparsable field prints ⚠ in amber,
> never 0 and never a raw boolean. "No data" and "the data is zero" must not look
> alike — that is the whole point of a status line you trust at a glance.

## The legend

Print order, line 1 then line 2. `#` matches the numbers on `docs/img/statusline-map.png`.

| # | Symbol / example | Meaning | Source | Threshold / colour |
|---|---|---|---|---|
| 1 | `Sonnet 5` / `⚠ modelo` | Model display name | `.model.display_name` | none — plain text or `⚠` |
| 2 | `·high` | Effort level, omitted if the field is null or absent | `.effort.level` | none |
| 3 | `▓░┋` (20 chars) | Context bar, 0..auto-compact span. `┋` marks the `context-red` band inside that span | `.context_window.current_usage.{input,cache_creation_input,cache_read_input}_tokens` (summed), or `.context_window.used_percentage × .context_window.context_window_size` as fallback | `context-red` (id, ≥300) red, `context-amber` (id, ≥150) amber, below both green — colour only when `rules/thresholds.json` loaded (`TH_OK`) |
| 4 | `123k/400k ⚠` | Tokens used / auto-compact ceiling in that unit. Trailing `⚠` when used ≥ `context-red` | used tokens as in #3; ceiling from `CLAUDE_CODE_AUTO_COMPACT_WINDOW` (accepts `400000`/`400k`/`1M`), else ~97% of `.context_window.context_window_size` | `context-red` id for the `⚠` |
| 5 | `62% of 1M` | Used tokens as % of the full window, and the window size itself (`k` or `M`) | `.context_window.context_window_size` | none |
| 6 | `$0.42` / `$⚠` | Cost estimate — reads `.cost.total_cost_usd` verbatim and prints it with `%.2f`. This is a payload figure Claude Code computes for the session, not a bill | `.cost.total_cost_usd` | none |
| 7 | `59m` / `⚠m` | Elapsed session time, `.cost.total_duration_ms / 60000` | `.cost.total_duration_ms` | none |
| 8 | `5h 96%` | 5-hour plan quota used. Blank (not `⚠`) when `.rate_limits` itself is `null` — that's "not tracked yet", a real state | `.rate_limits.five_hour.used_percentage` | `quota-5h` (id, ≥90) drives the hint (#18), no bar colour of its own |
| 9 | `7d 40%` | 7-day plan quota used, same null-vs-missing rule as #8 | `.rate_limits.seven_day.used_percentage` | none defined in thresholds.json |
| 10 | `⚡ caliente · 42m` / `⚡ enfriando · 4m` / `❄ fría · próximo turno reescribe` / `⚠ caché` | Cache state, **line 1**, right after #7: one word and one number, in one place. `caliente` (green) = warm, minutes until `expires_at`; `enfriando` (amber) = warm with ≤ `cache-cooling` minutes left; `fría` (cyan) = expired or `warm=false`, so the next turn pays to rewrite the context; `⚠ caché` = the object has an unknown shape. Blank when `.prompt_cache` is `null` (before the first call). The words come from `labels` in thresholds.json; without them only `⚡`/`❄` and the number print | `.prompt_cache.warm`, `.prompt_cache.expires_at` | `cache-cooling` (id, ≤5 min) amber + hint (#18) |
| 11 | `hit 72%` / `hit ⚠` | Cache hit ratio, **line 2**, shown only when it informs: below `cache-hit-ok`. At or above it the state in #10 says everything. Uncoloured and always shown when thresholds.json could not be read | `.prompt_cache.hit_ratio` (×100, floored) | `cache-hit-ok` (id, ≥85) hides it; amber below that; red below `cache-cold` (id, <60), which also drives the hint |
| 12 | `(3 miss)` / `(⚠ miss)` | Cache miss count, printed next to #11 when that is shown and the count is >0; `(⚠ miss)` always when unreadable | `.prompt_cache.misses` | none |
| 13 | `+931/-5` / `⚠ diff` | Lines added/removed this session, shown only when either is >0 | `.cost.total_lines_added`, `.cost.total_lines_removed` | none |
| 14 | `⎇ main ↑1 ↓0 ●3 ?1`, `⊘` | Branch, commits ahead/behind upstream, modified count, untracked count. `⊘` replaces the ahead/behind pair when there is no upstream | `git -C <dir> status --porcelain=v2 --branch`, run against `.workspace.current_dir` | `unpushed` (id, ahead>0, param 7200s) turns `↑N` amber once the oldest unpushed commit is ≥2h old, and drives the hint (#18) |
| 15 | `✓HANDOFF` / `⚠HANDOFF 14:05 ·4f ·1c ·0s` / `⚠ sin HANDOFF` | HANDOFF.md drift: the clock time of its mtime (`dd/mm HH:MM` when it is from another day; a clock time does not freeze between redraws, an age does), dirty files newer than it, commits since it (excluding a commit that only touches HANDOFF.md), sessions started since (from `~/.claude/logs/events.jsonl`) | `drift_scan()` in the script; sessions counter needs `HOME` and a readable event log | red when `handoff-drift-files` (id, >20f) or `handoff-drift-sessions` (id, ≥2s) fires, else amber; `✓` green; "sin HANDOFF" amber |
| 16 | `⚠ umbrales` | `rules/thresholds.json` missing, unreadable, or failed to parse this render — bands and hints are off | absence of `$TH_FILE` or `th_load` failure | n/a — this line means thresholds could not be checked at all |
| 17 | `[nombre-sesion]` | Session name, omitted if absent | `.session_name` | none |
| 18 | magenta hint text, e.g. `↑1 sin push → git push` | ONE hint: highest-priority threshold that fires right now, worded from `actions.default`/`actions.fresh`/`actions.nodata` in thresholds.json | `th_pick()` walks thresholds sorted by `priority` (ascending, lower fires first): `quota-5h` → `context-red` → `cache-cooling` → `cache-cold` → `session-long` (gated on `context-amber` also firing) → `unpushed` | colour is always magenta; which threshold wins is entirely priority order in `rules/thresholds.json`, never a number in this script |

### Special full-line states (pre-empt everything above)

| Symbol | Meaning | Source |
|---|---|---|
| `⚠ jq` (red) | No `jq` binary found on `PATH` or the WinGet link shim | script startup, before any payload is read |
| `⚠ JSON` (red) | The one `jq` call over stdin produced nothing at all — payload of an unknown shape | the render function's first jq call |
| `⚠ contexto` (amber) | Token usage or window size individually unreadable (distinct from the bar in #3, which needs both) | `.context_window.*` |

## Why absolute tokens, not %

> Why absolute tokens and not % of window: quality degrades at an absolute size, not a
> proportional one. 366k is a lot of context whether the window is 200k or 1M.
> Why the bar tops out at RED_K: it is a risk gauge, not a fuel gauge.
> The ┋ mark is where auto-compact will fire, so you can see the two limits at once.

## Tunables

Environment variables read by the script header, e.g. under `settings.json`'s `"env"`:

- `CC_CTX_GREEN_K` — override the `context-amber` threshold (default: thresholds.json)
- `CC_CTX_RED_K` — override the `context-red` threshold (default: thresholds.json)
- `CC_BAR_WIDTH` — bar width in characters (default 20)
- `CC_STATE_DIR` — where the `/ahora` snapshot is written (default `~/.claude/state`)
- `CC_NOW` — override "now" in epoch seconds, used by `--selftest` only

## More

See `docs/statusline-internals.md` for the 2.1.275 payload change (`.permission_mode`
dropped, why it produced `❄true%/0` and a false "sin HANDOFF"), the exact definition of
drift, and the procedure to re-capture a payload sample when Claude Code changes it again.
