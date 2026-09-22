# HANDOFF.md and drift

## What it is

`HANDOFF.md` at the repo root is session memory: state, decisions, what
failed, and next steps, written so a fresh session can continue without
re-exploring the codebase or re-reading the conversation. It is written by
the `handoff` skill (`home/.claude/skills/handoff/SKILL.md`) before closing,
before compacting, or when context reaches the red band of
`rules/thresholds.json`.

Fixed sections, exact headings:

```markdown
# HANDOFF — <project>  (updated: <ISO date>)

## Goal (1-2 lines)
## Current state
- DONE: ...
- IN PROGRESS: <step> — <exactly where it stopped, file:line if relevant>
- BLOCKED: ...
## Decisions (with the reason, one line each)
## Tried and failed (so nobody retries it)
## Next steps (ordered, each with its verification)
1. ...  → verify: `<command>`
## Commands that matter
- test: ...
- run: ...
## Open questions for the owner
```

Rules from the skill: facts only, no narrative (anything derivable from code
or `git log` stays out); "IN PROGRESS" must let someone continue without
reading the conversation; keep it under 120 lines, older detail moves to
`docs/handoffs/YYYY-MM-DD.md`; after writing, print `git status --short` and
remind the user to commit `HANDOFF.md` if the project tracks it.

## `verify.sh` runs first, every session

`verify.sh` checks what the current `HANDOFF.md` claims is done, not what it
says. The header comment states the reason directly: a HANDOFF that asserts
something false is worse than having none, because work gets planned on top
of it — this already happened once, when a HANDOFF claimed a tool was not
installed when it had been for three weeks, costing two unnecessary plan
steps. The script exits 0 only if every check passes.

## Drift: one definition

Drift has exactly one definition: `drift_scan` inside `home/.claude/statusline.sh`,
exposed as `statusline.sh --drift <dir>`, which prints five fields on one line:

```
state hage f c s
```

- `state` — `ok` (nothing moved since HANDOFF.md was written), `stale`
  (drift detected), or `none` (no HANDOFF.md at all).
- `hage` — hours since `HANDOFF.md`'s mtime.
- `f` — dirty files newer than `HANDOFF.md`.
- `c` — commits since `HANDOFF.md`'s mtime.
- `s` — sessions started for this project since then, read from
  `~/.claude/logs/events.jsonl`.

Both `session-drift-warn.sh` (the `SessionStart` hook) and the status line
call this same function, so they cannot disagree.

## The red band lives in `rules/thresholds.json`, not in code

Drift turns red at the `handoff-drift-files` and `handoff-drift-sessions`
thresholds defined in `home/.claude/rules/thresholds.json` — currently
`> 20` dirty files or `>= 2` sessions. Neither the status line nor the hook
hardcodes these numbers; both read the same JSON entries by id.

## A commit that only touches HANDOFF.md does not count

Committing the handoff itself does not change `HANDOFF.md`'s mtime relative
to itself, but `drift_scan` explicitly excludes a commit whose only changed
file is `HANDOFF.md` from the `c` (commits-since) count. Without this rule
the bar would go stale the instant a handoff is committed — exactly when it
is freshest.

## Counters show `?`, never `0`

Any of `f`, `c`, `s` that cannot be computed shows `?`. It never downgrades
to `0` and never downgrades to the `none` state — `none` means the file is
genuinely absent, not that a counter failed to compute.

## After a handoff: `/clear` by default

Once `HANDOFF.md` is written and drift is fresh, `/clear` is the default —
it is reversible and the prior session stays resumable. `/compact` is used
only when the same thread must continue; it is a lossy operation, so it is
scheduled deliberately, not reached for out of habit.

## The PreCompact draft leaves the judgment blank on purpose

`precompact-draft.sh` appends mechanical facts to
`docs/handoffs/<date>-draft.md` on every `PreCompact`: branch, commits since
the session's first `SessionStart`, uncommitted files, failed commands, and
the current drift reading. From `docs/statusline-internals.md`:

> The draft collects facts and stops there. It does not write "where we are
> and why", because that is the judgment that makes a handoff worth reading,
> and a plausible machine-written paragraph in that slot is worse than a
> blank one — it looks like someone thought about it. That part stays
> yours, or `/handoff`'s.

The draft cannot fill that gap even if it wanted to: `PreCompact` stdout is
never shown to the user, only logged for debugging, so the draft file is the
only place that notice can land.
