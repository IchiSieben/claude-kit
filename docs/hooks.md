---
lesson:
  route: code-like-me
  order: 5
  level: 2
---

# Hooks

Five scripts under `home/.claude/hooks/`, wired in `home/.claude/settings.json`.
Every hook always exits 0 — a hook must never be the reason a session, a
compaction, or the tool it watches fails.

## Table

| Event · matcher | Script | Writes |
|---|---|---|
| `SessionStart` (`compact`) | `compact-reinject.sh` | stdout only (no file) |
| `SessionStart` (`startup\|resume\|clear\|compact`) | `log-event.sh` | `~/.claude/logs/events.jsonl` |
| `SessionStart` (`startup\|resume\|clear`) | `session-drift-warn.sh` | stdout only (no file) |
| `PreCompact` | `log-event.sh` | `~/.claude/logs/events.jsonl` |
| `PreCompact` | `precompact-draft.sh` | `docs/handoffs/<date>-draft.md` |
| `PostCompact` | `log-event.sh` | `~/.claude/logs/events.jsonl` |
| `SubagentStop` | `log-event.sh` | `~/.claude/logs/events.jsonl` |
| `SessionEnd` | `log-event.sh` | `~/.claude/logs/events.jsonl` + sweeps `~/.claude/state/` |
| `PostToolUseFailure` (`Bash`) | `log-tool-failure.sh` | `~/.claude/logs/tool-failures.jsonl` |

`log-event.sh` is one script reused across six event/matcher combinations; it
reads `hook_event_name` from its own payload to decide what else to do.

## Contract facts

- **`SessionStart` stdout is added to the session context.** This is the only
  reason `session-drift-warn.sh` reaches the user at all. Because it costs
  tokens on every startup, it prints nothing unless HANDOFF drift is in the
  red band — a warning shown on every session is one nobody reads by day
  three.
- **`PreCompact` stdout goes to the debug log only** — not shown, not
  injected. `precompact-draft.sh` writes the "you still owe the judgment
  part" notice *inside the draft file*, not to stdout, because stdout would
  never reach the user here.
- **`PreCompact` exit code 2 blocks compaction.** Every hook in this kit
  exits 0 for exactly that reason: a draft or a log line that fails to write
  must never cost the user a compaction.
- **`PostToolUseFailure` (`Bash`) payload**, captured from a real run: `session_id`,
  `transcript_path`, `cwd`, `scratchpad_dir`, `prompt_id`, `permission_mode`,
  `effort.level`, `hook_event_name`, `tool_name`, `tool_input.{command,description}`,
  `tool_use_id`, `error`, `is_interrupt`, `duration_ms`. `PostToolUse` fires on
  success only; failures arrive through this separate event. `tool_response`
  is `null` on failure, so there is no structured exit code — the script
  keeps the first line of `error` (`"Exit code N"`) instead of inventing one.

## Redaction before disk

`log-tool-failure.sh` redacts the captured command *before* it is written,
not after — truncation alone does not protect a secret at character 10.
Patterns redacted (see the script for the exact `gsub` calls):

- Provider-style keys: `sk-`, `ghp_`, `gho_`, `ghs_`, `github_pat_`,
  `xox[baprs]-`, `AKIA`, `ASIA`.
- `Bearer <token>` / `Basic <token>` / bare `token <value>`, handled as its
  own rule before the generic one, so the auth-scheme word itself is not
  mistaken for the secret.
- `key=value` / `key: value` pairs where the key looks like `token`,
  `password`, `passwd`, `secret`, `api[-_]?key` or `authorization`.
- `--pass`, `--password`, `--token`, `--secret` flags.
- The command is then truncated to 160 characters.

## `is_interrupt` is not logged

`log-tool-failure.sh` filters out any payload where `is_interrupt` is `true`
before writing. That flag means the user stopped the command — it is not a
failed command and must not be recorded as a lesson.

## 24h sweep on `SessionEnd`

`log-event.sh`, when the event is `SessionEnd`, deletes files under
`~/.claude/state/` (or `$CC_STATE_DIR`) older than 1440 minutes (24h). The
status line writes one small snapshot per session there and nothing else
ever removed them. 24h is the cutoff because a snapshot is only useful to
`/ahora` while its session is still alive, and a live session's snapshot is
rewritten on every render — so a file untouched for a day belongs to a
window that is already gone.

## Post-compact re-anchor

`compact-reinject.sh` runs on `SessionStart` with matcher `compact`, and its
stdout is injected into the freshly compacted context (that path *is*
shown). It prints:

- `=== POST-COMPACT RE-ANCHOR ===`
- the first 80 lines of `HANDOFF.md` if present, or a note that it is
  missing and `/handoff` should run before continuing long work
- `git log --oneline -5`
- `git status --short` (first 15 lines)
- a closing rule: re-read the current step in `HANDOFF.md` before acting, do
  not redo completed steps

## What `tests/hooks_test.sh` checks

It covers all four distinct scripts — `log-tool-failure.sh`,
`precompact-draft.sh`, `session-drift-warn.sh` and `log-event.sh` — against
synthetic stdin payloads shaped like a captured 2.1.276 run, using a
throwaway git repo and a fake `HOME` kept *outside* that repo. Keeping
`HOME` outside matters: a log file created inside the repo would count as a
dirty file newer than `HANDOFF.md` and poison the drift counters under test.
