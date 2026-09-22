# thresholds.json

Source: `home/.claude/rules/thresholds.json` (full file), `docs/statusline-internals.md`
§Thresholds, `home/.claude/statusline.sh`, `home/.claude/hooks/session-drift-warn.sh`,
`tests/statusline_test.sh`.

## The one place the numbers live

`rules/thresholds.json`'s own `_readme` states the rule the file enforces:
code looks thresholds up by `id`, never by position; a missing or unreadable
file is not a license to fall back to a hardcoded default — the bar prints
an amber `⚠ umbrales` warning and stops colouring and hinting instead,
"because a threshold you cannot read is not the same thing as a threshold
that is not crossed."

## All entries

Values below are current as of the file's `confirmed` line: `2026-09-18 —
owner confirmed every value below unchanged from statusline.sh`.

| id | measures | condition | value | priority | action |
|---|---|---|---|---|---|
| `quota-5h` | 5-hour quota used | `five_pct >=` | 90 | 10 | stop, or drop to `sonnet` |
| `context-red` | context size | `context_k >=` | 300 (k tokens) | 20 | `/handoff` first, then `/clear` |
| `cache-cold` | prompt-cache hit rate | `cache_pct <` | 60 | 30 | name the cause (or `/usage` if unknown) |
| `session-long` | session length | `session_min >=` | 480 (8h) | 40 | `/handoff` before `/clear` (gated on `context-amber`) |
| `unpushed` | commits ahead of upstream | `ahead >` | 0 | 50 | `git push` (`param: 7200`s grace before the counter turns amber) |
| `context-amber` | context size | `context_k >=` | 150 (k tokens) | 60 | band only, no hint |
| `handoff-drift-files` | dirty files newer than HANDOFF.md | `handoff_dirty >` | 20 | 70 | band only, no hint |
| `handoff-drift-sessions` | sessions since HANDOFF.md | `handoff_sessions >=` | 2 | 71 | band only, no hint |

Priority is lowest-fires-first: the status line shows one hint, the lowest
`priority` value among the thresholds whose condition currently matches.
`hint: false` entries (`context-amber`, both `handoff-drift-*`) only gate
colour or another threshold — the `session-long` entry's `gate` field, for
example, requires `context-amber` to also hold before its hint fires.

A metric the caller could not measure is reported as `-1` and never matches
any condition — unknown is deliberately not the same as zero.

## Who reads it

`home/.claude/statusline.sh` (the bar), `home/.claude/hooks/session-drift-warn.sh`
(the drift warning on `SessionStart`), and `/ahora`. None of the three
carries a threshold number in its own code; all three look up
`rules/thresholds.json` by id at run time.

## Missing or unparsable file

Both cases are tested in `tests/statusline_test.sh` and land on the same
result: no bands, no hints, never a remembered default.

- **File missing**: `statusline.sh` reports `TH_FILE=""` and the bar prints
  `⚠ umbrales`.
- **File present but does not parse** (the test writes a truncated/invalid
  JSON body): the bar still exits 0, still prints `⚠ umbrales`, and gives no
  hint that could be mistaken for real advice (the test asserts neither
  `/handoff` nor "límite 5h" text appears in that case). `/ahora` reports
  "no puedo leer los umbrales" instead of three normal lines of state.

`session-drift-warn.sh` follows the same rule on its own: if
`rules/thresholds.json` cannot be read or `jq` cannot parse the two drift
conditions out of it, the hook exits silently rather than warning — no
red band is computable, so none is claimed.

## How to change a threshold

1. Edit the value (or condition/priority/action) in
   `home/.claude/rules/thresholds.json`, and update its `source` line if the
   justification changed.
2. Run `bash tests/statusline_test.sh` and `bash tests/hooks_test.sh`.
3. Run `sync-to-home.sh` to mirror the edited repo copy to `~/.claude/`
   (`sync-to-home.sh` copies exactly what `mirror_list` in `mirror-lib.sh` prints, and
   that list includes `rules/*.json`, so the file travels with the rest of the mirror).

## Env overrides

`CC_CTX_GREEN_K` and `CC_CTX_RED_K` override `context-amber` and
`context-red` respectively at run time, without editing the JSON — read
directly by `statusline.sh` ahead of the thresholds-file lookup.

## It travels in the mirror

`mirror-lib.sh` includes `rules/*.json` (alongside `rules/*.md`, `hooks/*.sh`
and `agents/*.md`) in the set of files it copies between the repo and
`~/.claude/`, so `rules/thresholds.json` is never a file a user edits in one
location but not the other.
