---
lesson:
  route: code-like-me
  order: 3
  level: 1
---

# Context hygiene

Source: `home/.claude/rules/context-hygiene.md`, `home/.claude/rules/thresholds.json`,
`home/.claude/settings.json`, `home/.claude/statusline.sh`, `home/.claude/MANUAL.md` ch. 2,
`home/.claude/CLAUDE.md` §Status line.

## Work between amber and red, in absolute tokens

The working band is defined by two ids in `rules/thresholds.json`:

- `context-amber` — currently `150` (thousand tokens, `context_k >= 150`).
- `context-red` — currently `300` (thousand tokens, `context_k >= 300`).

Below amber: keep going. Between amber and red: still fine, but plan a
milestone to compact at. At red: propose `/handoff` first, then `/clear`.
`/compact` only when the same thread must continue. Neither number is
written in `statusline.sh` or in any hook — both read the JSON by id, so
there is exactly one place to change them.

## Why percentage of the window is the wrong rule

`rules/context-hygiene.md` states it directly: *"Percentage of the window is
NOT the rule: 60% of 1M is twice the red band."* Quality degrades at an
absolute context size, not at a proportional one — 300k tokens is a lot of
context whether the window is 200k or 1M. `statusline.sh`'s own header
comment makes the same point: *"Why absolute tokens and not % of window:
quality degrades at an absolute size, not a proportional one. 366k is a lot
of context whether the window is 200k or 1M."*

## `┋` marks the auto-compact ceiling

`home/.claude/settings.json` sets `env.CLAUDE_CODE_AUTO_COMPACT_WINDOW` to
`400000`. The status line marks this point on its bar as `┋`. It sits above
`context-red` (300k) on purpose: `statusline.sh`'s header frames the bar as
*"a risk gauge, not a fuel gauge"* — the `┋` mark shows where auto-compact
will fire so the two limits are visible at once, but the red band at 300k is
where the user is expected to act first. Compaction is a lossy event meant
to be scheduled deliberately after a handoff, not one that should happen to
the session because nobody looked at the bar.

## At red: `/handoff` first, then `/clear`

From `home/.claude/CLAUDE.md` §Status line:

| Signal | Proposed action |
|---|---|
| context in the red band | `/handoff` FIRST, then `/clear` — `/compact` only if this thread must continue |

`/clear` is reversible and leaves the prior session resumable; `/compact` is
not, so it is reserved for when the thread genuinely has to keep going.

## Milestone compaction beats emergency compaction

From `rules/context-hygiene.md`: compact after plan approval, after tests
pass, or before starting a new unrelated task — not only when forced to by
the red band. Waiting for the red band or for auto-compact is choosing the
worst possible moment to lose context.

## Never paste full logs, datasets, or HTML

Summarize to at most 20 lines, keeping the exact lines that matter. This
applies to logs, datasets, and raw HTML alike — the rule is about volume
pasted into context, not the source's format.

## One task per session

An unrelated question mid-session is a signal to use `/btw` or `/clear`,
not to keep working across two unrelated goals in the same context.
