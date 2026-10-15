# SPEC — harvest.py v2 and partidas.py ("sessions as matches")

Status: contract for ecosystem prompt §19 item 3 (2026-10-15). Stdlib only, read-only on
`~/.claude/projects/`, nothing leaves the machine.

## Facts measured before writing this (2026-10-15, 153 transcripts)

- An assistant message is stored as one record per content block, every copy with the SAME
  `message.usage` (5 674 duplicate groups, 0 differing). v1 summed every copy: its token
  totals are inflated (up to ~2x). v2 counts each `message.id` once.
- No `costUSD` on messages. A `type: "cost-state"` record carries `modelUsage{model:{...,
  costUSD}}`, cumulative and monotonic (114/114 files). The LAST one is the session's cost
  as the harness computed it.
- Price-table estimate (models.json) vs cost-state: 0.28–1.0x without subagents, 0.6–1.0x
  with `<session>/subagents/*.jsonl` added. The gap is not explained (advisor calls, server
  tools, resumed sessions are candidates). So: harness cost when present; otherwise the
  estimate, flagged `cost_source: "estimate"` and described as a lower bound.
- Subagent transcripts live in `projects/<proj>/<session-id>/subagents/*.jsonl`.
- Commands appear as `<command-name>/clear</command-name>` inside user text; compaction is
  `type: "system", subtype: "compact_boundary"`; `system/turn_duration` has `durationMs`.
- Records carry `cwd`. `projects/<dir>` names are path-encoded (`C--Users-<name>-...`).

## Inputs

- `--claude-dir` (default `$CLAUDE_CONFIG_DIR` or `~/.claude`): `projects/*/*.jsonl`,
  `projects/*/<sid>/subagents/*.jsonl`.
- `rules/thresholds.json` and `rules/models.json`, looked up in `<claude-dir>/rules/`, then
  in `home/.claude/rules/` next to the script. If either cannot be read: print which file and
  exit 2. **Never fall back to a number written in the code.**
- `~/claude-archive/sessions.json` (the archive harvest.py maintains).

## harvest.py v2 (same CLI, same archive file, extended records)

Keep every v1 key (visor and verify read them). Add per session:

| key | definition |
|---|---|
| `harvest_version` | `2` |
| `project_label` | basename of the most frequent `cwd` in the session; `home` if it is the home dir |
| `bytes` | size of the main `.jsonl` plus its `subagents/*.jsonl` |
| `turns` | typed human prompts (v1 `user_turns` rule), excluding `isSidechain` and `isMeta` records and command records |
| `commands` | counts of `/clear`, `/compact`, `/handoff` from `<command-name>` (non-sidechain only), plus `Skill` tool calls with skill `handoff` added to `/handoff` |
| `compactions` | number of `compact_boundary` records |
| `compactions_without_handoff` | compactions with no `/handoff` (command or Skill) since the previous compaction or session start |
| `models` | v1 shape, but each `message.id` counted once (records without an id count once each) |
| `subagents` | same shape as `models`, from the subagent transcripts, deduped the same way |
| `cost_usd` | last `cost-state` total if any (`cost_source: "harness"`), else the models.json estimate over main + subagents (`cost_source: "estimate"`), else 0 (`"none"`). Cache writes priced by `usage.cache_creation.ephemeral_5m/1h_input_tokens` when present, else all at the 5m price |
| `peak_context` | max over deduped main-chain requests of `input + cache_read + cache_write` |
| `hit_pct` | `100 * cache_read / (input + cache_read + cache_write)` over the main chain (the bar's ratio) |
| `cold_cache_events` | main-chain requests, excluding the first one and the first one after a compaction or `/clear`, whose own hit% is below `cache-cold` (thresholds.json, `cache_pct <` value) |
| `active_ms` | sum of `system/turn_duration.durationMs` |
| `duration_min` | `last_seen - first_seen` in minutes |
| `start_hour_local` | local-time hour (0-23) of `first_seen` |

Sessions that are only in the archive (transcript deleted) keep their v1 record untouched.
Before writing, the first v2 run copies the archive to `sessions.v1-backup.json` if that
file does not exist yet.

## partidas.py (new)

`python partidas.py [--archive DIR] [--claude-dir DIR] [--weeks 4] [--now ISO]`
(`--now` pins "today" for tests). Writes into the archive dir:

1. `partidas.json` — `{generated, window_weeks, thresholds_used, sessions_v2, sessions_v1_only,
   per_session[], by_project[], by_week[], plays[], disk_by_project[]}`.
2. `partidas.html` — one file, no network (no `<script src>`, no `<link href=http>`, no
   `url(http`), inline CSS + hand-written SVG, no libraries. Identity of the enjambre visor:
   dark `--bg:#0D1117 --fg:#E6EDF3 --muted:#8B949E --accent:#2DD4BF`, light `--bg:#FFFFFF
   --fg:#1F2328 --muted:#59636E --accent:#0D9488`, via `prefers-color-scheme`; monospace
   stack `"JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace`, text
   stack `"Space Grotesk", system-ui, sans-serif` (local fonts only, no download). Blocks:
   headline numbers for the window; cost per week (bars); hit% per week (line + the
   `cache-cold` and `cache-hit-ok` lines); tokens and cost by project (bars); start hour
   histogram; plays table; disk by project. Real figures only; empty data shows "sin datos".
   Spanish copy.
3. `partidas.txt` — interview summary in Spanish, <= 12 lines, last `--weeks` weeks: sessions,
   hours, cost, hit%, top projects by cost, plays by rule, one sentence of what changed.

Privacy (asserted by tests): outputs carry `project_label` only, never `project` (the encoded
dir), `file`, `cwd`, session ids (use a 1-based index sorted by start), prompt text, or the
user name. Labels matching the extended regex in `$KIT_PROTECTED_PATHS` (unset: nothing
matches) become `privado-N`.

### Plays (rules are explicit; each row names its rule and the numbers that fired it)

| id | fires when |
|---|---|
| `long-no-handoff` | `peak_context >= context-red*1000` (thresholds.json) and `commands./handoff == 0` |
| `strong-on-mechanical` | dominant model by output tokens has `tier` in `{frontier, flagship}` (models.json) AND >= 5 tool calls AND >= 80 % of them in `{Read, Grep, Glob, Bash, PowerShell, WebFetch}` AND no `Edit`/`Write`/`NotebookEdit`/`Agent`/`Task` call. Heuristic, labelled so. |
| `cold-cache` | `cold_cache_events > 3` |
| `compact-no-handoff` | `compactions_without_handoff >= 1` |

Only `harvest_version == 2` sessions are judged; the count of v1-only sessions is reported.

### Aggregates

`by_week`: ISO week of `first_seen` (local), sessions, turns, tokens (in/out/read/write),
cost, hit%, plays. `by_project`: same per `project_label`. `disk_by_project`: bytes of every
file under `projects/<dir>/` (subdirs included), keyed by the label of that dir's sessions
(`sin-sesiones` if none parse), sorted desc — §18 (disk emergency) needs it.

## Tests — `tests/partidas_test.sh`

Generates synthetic transcripts in `mktemp -d` (with an embedded python writer), with its own
`rules/` copied from `home/.claude/rules/`, runs harvest.py then partidas.py with `--now`,
and asserts: dedupe (3 copies of one message count once); cost from cost-state vs estimate;
each play fires exactly where planted and nowhere else; `compactions_without_handoff`;
`/clear` excluded from turns; sidechain commands ignored; disk bytes; privacy: none of the
three outputs contains the planted user name, `C--`, `C:\`, `/Users/`, a session id, or the
planted prompt sentinel; the HTML has no `http` reference; missing thresholds.json exits 2.

## Out of scope

Uploading anything; reading `history.jsonl`; per-message timelines; editing visor.py.
