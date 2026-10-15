# harvest, partidas and bitacora

Source: `harvest.py`, `partidas.py`, `bitacora.py`, `SPEC-partidas.md` (including its
"Facts measured" section), `docs/bitacora-spec.es.md`, `tests/partidas_test.sh`,
`tests/bitacora_test.sh`, `home/.claude/rules/thresholds.json`, `home/.claude/rules/models.json`.

## What it is

- `harvest.py` keeps metrics from Claude Code transcripts before the 30-day sweep deletes them.
- `partidas.py` turns those metrics into "sessions as matches": per session, which of four
  habits the kit teaches were broken, plus weekly and per-project totals.
- `bitacora.py` answers "where did each project stop and where do I resume".

All three are local, stdlib-only and read-only on `~/.claude`. Nothing is uploaded.

## Run it

Run the commands from the repo root, where the three scripts live.

```
python harvest.py
python partidas.py
python bitacora.py
```

| Command | Writes to `~/claude-archive/` |
|---|---|
| `harvest.py` | `sessions.json`; `sessions.v1-backup.json` (copied once, on the first v2 run) |
| `partidas.py` | `partidas.json`, `partidas.html`, `partidas.txt` |
| `bitacora.py` | `bitacora.html`, `bitacora.json` |

`partidas.py` reads `sessions.json`, so run `harvest.py` first. If `sessions.json` cannot be
read, `partidas.py` stops and says so.

Flags:

| Flag | Applies to | Meaning |
|---|---|---|
| `--claude-dir DIR` | all three | Claude config dir. Default `$CLAUDE_CONFIG_DIR`, else `~/.claude`. |
| `--out DIR` | `harvest.py`, `bitacora.py` | Output dir. Default `~/claude-archive`. |
| `--archive DIR` | `partidas.py`, `bitacora.py` | Where `sessions.json` lives (and, for `partidas.py`, where it writes). Default `~/claude-archive`. |
| `--report-only` | `harvest.py` | Print what the archive holds; read no rules, write nothing. |
| `--weeks N` | `partidas.py` | Window length. Default 4. |
| `--now ISO` | `partidas.py`, `bitacora.py` | Pin "today". Used by the tests. |
| `--root DIR` | `bitacora.py` | Folder whose subfolders are the projects. Default: the folder that holds the repo. |
| `--dry-run` | `bitacora.py` | List detected projects and the source of each field; write nothing. |
| `--include-prompts` | `bitacora.py` | Also write the last prompt text into `bitacora.json`. |

`bitacora.py` also accepts `--projects FILE` and `--visor-dir DIR`.

Tests:

```
bash tests/partidas_test.sh
bash tests/bitacora_test.sh
```

Both build synthetic data in a temporary directory and never read the real home.

## What changed in v2 and why

Two facts were measured on 153 transcripts (2026-10-15).

**Duplicated usage.** Claude Code stores one record per content block of an assistant message.
Every copy carries the same `message.usage` (5,674 duplicate groups, none with differing
values). v1 summed every copy, so its token totals were inflated, up to about 2x. v2 counts
each `message.id` once; a record without an id counts once. Sessions that are only in the
archive (their transcript is gone) keep their v1 record and v1 numbers. They are flagged as
v1-only and counted in the report, never judged.

**Cost.** Messages carry no cost field. A `cost-state` record carries a cumulative,
monotonic `costUSD` per model (present and monotonic in 114 of 114 files that had one). v2
uses the last `cost-state` record: `cost_source: "harness"`. When a session has none, it
estimates from `models.json` prices: `cost_source: "estimate"`.

The estimate is a lower bound. Against the harness figure it measured 0.28-1.0x without
subagent transcripts and 0.6-1.0x with them added. The gap is not explained. Advisor calls,
server-side tools and resumed sessions are candidates; none is confirmed. Do not read an
estimate as the true cost.

Cache writes are priced by `cache_creation.ephemeral_5m/1h_input_tokens` when present,
otherwise all at the 5-minute price. A model missing from `models.json` is priced at 0, not
guessed.

## Per-session fields

Every v1 key is kept. v2 adds:

| Field | Meaning |
|---|---|
| `harvest_version` | `2`. |
| `project_label` | Basename of the most frequent `cwd`; `home` if that is the home dir. |
| `bytes` | Size of the main `.jsonl` plus its `subagents/*.jsonl`. |
| `turns` | Typed human prompts, excluding sidechain, meta and command records. |
| `commands` | Counts of `/clear`, `/compact`, `/handoff`. A `Skill` call to `handoff` counts as `/handoff`. |
| `compactions` | Number of `compact_boundary` records. |
| `compactions_without_handoff` | Compactions with no handoff since the previous compaction or the session start. |
| `models`, `subagents` | Tokens and requests per model, deduplicated by `message.id`; main chain and subagent transcripts. |
| `cost_usd`, `cost_source` | Cost and where it came from: `harness`, `estimate` or `none`. |
| `peak_context` | Largest `input + cache_read + cache_write` of one main-chain request. |
| `hit_pct` | `100 * cache_read / (input + cache_read + cache_write)` over the main chain. |
| `cold_cache_events` | Main-chain requests whose own hit rate is below `cache-cold`, excluding the first request and the first one after a compaction or `/clear`. |
| `active_ms` | Sum of `turn_duration` records. |
| `duration_min` | Last timestamp minus first, in minutes. |
| `start_hour_local` | Local hour (0-23) of the first timestamp. |

## The four plays

`partidas.py` judges only `harvest_version == 2` sessions. Each play in the output names its
rule and the numbers that fired it.

| Play | Fires when | Number comes from |
|---|---|---|
| `long-no-handoff` | `peak_context >= context-red * 1000` and `/handoff` count is 0 | `thresholds.json`, id `context-red` (300 k at the time of writing) |
| `strong-on-mechanical` | The model with the most output tokens has `tier` `frontier` or `flagship`; at least 5 tool calls; at least 80 % of them in `Read, Grep, Glob, Bash, PowerShell, WebFetch`; no `Edit`, `Write`, `NotebookEdit`, `Agent` or `Task` call | `models.json`, field `tier`. The 5 and the 80 % are written in the code. |
| `cold-cache` | `cold_cache_events > 3` | `thresholds.json`, id `cache-cold` (hit below 60 % at the time of writing). The 3 is written in the code. |
| `compact-no-handoff` | `compactions_without_handoff >= 1` | None; it is a count. |

`strong-on-mechanical` is a heuristic. It infers the kind of work from the tool mix and cannot
see intent. Treat a hit as a question, not a verdict.

The code has no numeric fallback for thresholds or prices. If `thresholds.json` or
`models.json` cannot be read in `<claude-dir>/rules/` or the kit's own copy, or an installed
`thresholds.json` lacks `context-red`, `cache-cold` or `cache-hit-ok`, the script names the
file and exits 2. Same rule as the status line: a threshold you cannot read is not one that
was not crossed. See `docs/thresholds.md`.

## Privacy

`partidas.json`, `partidas.html` and `partidas.txt` carry the project label only. They never
carry the encoded project dir, file path, `cwd`, session id, prompt text or user name.
Sessions are numbered 1..N by start time. A label matching the extended regex in
`$KIT_PROTECTED_PATHS` is shown as `privado-N` (unset: nothing matches). The tests assert
these absences and that the HTML contains no `http` reference.

`sessions.json` keeps metadata only: no message content, no prompt text. It still holds
`file` and `project` paths, so it is the local archive, not an output to publish.

`bitacora.json` omits prompt text unless you pass `--include-prompts`. `bitacora.html` is for
you only: it shows the last prompt per project and links to local folders, so do not publish it.
The page makes no network request.

## Disk

Transcripts grow until the sweep removes them. `partidas.py` reports the size of every file
under each `projects/<dir>/` (subagent transcripts included), grouped by project label and
sorted largest first (`disk_by_project`). A dir with no parsable session appears as
`sin-sesiones`.

## Overlap with the enjambre visor

The enjambre visor shows nodes, the queue, live sessions, quota and tokens per day.
`bitacora` does not repeat that: it shows one 30-day token and cost number per project and
links to the visor. `partidas` is the weekly and aggregate view: how habits and cost moved
over the last weeks, not what is running now.

## Limits

- The 30-day sweep makes any older window a sample. `partidas.py` refuses to compare windows
  that the archive cannot cover fully.
- `turns` counts typed prompts only. Tool results, command records and sidechain prompts are
  excluded, so it does not measure effort or output.
- Times are local. `start_hour_local` and the ISO week of `by_week` use the machine's time zone.
- Cost for `estimate` sessions is a lower bound (see above), and v1-only sessions have
  inflated tokens and no cost judgement.
