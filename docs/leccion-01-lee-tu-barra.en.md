---
lesson:
  route: code-like-me
  order: 1
  level: 0
---

# 01 — Read your bar: what Claude Code is telling you on every turn

## Goal

Look at the two lines of the status bar and know, at a glance, four things: how much context you
have left before the session degrades, whether the cache is still warm, whether your work is
safe (commit, push, HANDOFF) and what you should do now. By the end you can read any state of
the bar without opening the legend.
**Who does it:** you. `home/.claude/statusline.sh` draws the bar on every turn; you only read it.

## Why: a bar that does not lie

Claude Code hands the bar a JSON payload on every turn (model, tokens, cost, quota, cache). The
easy thing is to paint those numbers as they come. The trouble is that a number that never
arrived and a number that is zero look the same, and you act differently on each. So the bar is
built on one rule:

> A field that is missing or unreadable is painted `⚠` in amber, never `0`.

The second rule is that **no threshold lives in the script**. The 150k and 300k context bands,
the 90 % quota, the 5 cache minutes: all of it is in `rules/thresholds.json`. If that file cannot
be read, the bar says `⚠ umbrales` and stops colouring. A threshold you cannot read is not the
same as a threshold that was not crossed.

The bar's own words are Spanish (`caliente`, `enfriando`, `sin push`); they come from
`thresholds.json` too, so you can translate them there.

## Steps

![The 18 sectors of the bar, by group](img/statusline-sectores.en.svg)

The numbers match the full legend, [`statusline.md`](statusline.md). Here they come by group, in
the order worth reading them.

## Step 1 — Model and context (#1–#5, line 1)

`Opus 5.5 ·high @mac ▓▓▓▓▓▓▓▓▓░░░░░░┋░░░░ 180k/400k · 18% of 1M`

- **#1 and #2**: model and effort level. `@mac` names the machine the session runs on; over
  Remote-SSH every window looks the same.
- **#3, the bar**: from 0 to where auto-compact fires. `┋` marks the red band (`context-red`,
  300k): that is where you should have cut. It is a risk gauge, not a fuel gauge.
- **#4**: tokens used / the auto-compact ceiling. Green below 150k, amber from 150k to 300k, red
  from 300k (with a trailing `⚠`).
- **#5**: the share of the real window. It is context, not the decision: quality drops at an
  absolute size, and 60 % of 1M is twice the red band.

## Step 2 — Cost and time (#6–#7)

`$7.10 · 90m`. The cost is the figure Claude Code computes for the session, not a bill. Minutes
count from when you opened the session: past 8 h, with context in amber, the hint suggests a cut.

## Step 3 — Cache (#10–#12): one word and one number

The prompt cache keeps your context for one hour. While it is warm, each turn reads it at the
read price; once it expires, the next turn pays to write all of it again. The bar says so in
**one place** on line 1:

| What you see | What it means |
|---|---|
| `⚡ caliente · 42m` (green) | 42 minutes until the last write expires (`expires_at`) |
| `⚡ enfriando · 4m` (amber) | 5 minutes or less left (`cache-cooling`). The hint says what to do |
| `❄ fría · próximo turno reescribe` (cyan) | It expired: the next message pays to rewrite the whole context |

The hit ratio (**#11**, `hit 79%`) moved to line 2 and **only shows when it tells you something**:
below 85 % (`cache-hit-ok`). Red below 60 % (`cache-cold`), and then the hint names the cause the
payload reports (`model_changed`, `effort_changed`…). **#12** is the miss count.

## Step 4 — Plan quota (#8–#9, line 2)

`5h 41%  7d 87%`: how much of the 5-hour window and of the weekly one you have used. If
`rate_limits` does not exist yet (before the first call) the sector stays blank: that is not an
error, it is "no data yet".

## Step 5 — Git (#13–#14)

`+213/-15  ⎇ main ↑1 ↓0 ●2 ?1`: lines added/removed this session, branch, commits not pushed
(`↑`) and not pulled (`↓`), modified (`●`) and untracked (`?`) files. `⊘` instead of `↑↓` means the
branch has no upstream. `↑1` turns amber once the oldest unpushed commit is more than 2 h old.

## Step 6 — HANDOFF (#15)

`HANDOFF.md` is the session's memory. Green `✓HANDOFF`: nothing moved after it was written.
`⚠HANDOFF 14:05 ·2f ·1c ·0s`: you wrote it at 14:05 and since then 2 files are newer than it,
there is 1 commit and 0 new sessions. Red past 20 files or 2 sessions. A `?` in a counter means
"could not be computed", never zero.

## Step 7 — The hint (#18) and the rest (#16–#17)

The magenta text at the end is **one** suggestion: the highest-priority threshold that holds
right now. The order is `priority` in `thresholds.json`: quota → red context → cache cooling →
low hit → long session → unpushed commits. It never shows two: a bar with two pieces of advice is
no longer glanceable. **#17** is the session name; **#16** (`⚠ umbrales`) only shows when
`thresholds.json` is missing or broken.

## What actually went wrong

- **`❄true%/0` and a false "sin HANDOFF" (2.1.275).** Claude Code dropped `.permission_mode` from
  the payload. The script read 17 tab-separated fields, and with `IFS=$'\t'` an empty field
  collapses: everything shifted by one. `hit` got `true`, the directory got a number and git
  failed. Fix: a `\x1f` separator, a sentinel per field and a field-count guard.
- **`❄96% /59m` contradicted itself.** A high hit ratio next to a snowflake, and a TTL that did not
  answer the real question ("how long do I have if I send nothing?"). That is where Step 3's
  redesign comes from (2026-10-15): the state is a word, the number is minutes and the hit only
  shows when it matters.
- **`$12,00` instead of `$12.35`.** Under an `es_ES` locale, `printf '%.2f'` reads and writes with a
  comma. The bar pins `LC_NUMERIC=C` and keeps your `LC_CTYPE` for the glyphs.
- **"50 min ago" for hours.** The bar only redraws on session events, so an age freezes. The
  HANDOFF now shows the **clock time** it was written.

## How to verify

```bash
bash tests/statusline_test.sh        # golden files + invariants: 67 cases
bash home/.claude/statusline.sh < tests/fixtures/cache-cooling.json
```

The second line paints the "cooling" state from a sanitised real capture (2.1.300). Set
`cache-cooling` to 60 in `rules/thresholds.json` and run it again: the same cache turns
"enfriando" without touching the script.

## Self-check

1. The bar shows `⚠m` where the time usually is. Is it a freshly opened session, or did the
   payload change shape?
2. You see `412k/967k` in green. Can that happen? What does it tell you about `thresholds.json`?
3. `⚡ caliente · 3m` never appears: what do you see instead, and why?
4. You have `❄ fría · próximo turno reescribe` with 380k of context. Do you carry on, or
   `/handoff` and `/clear`? What changes in the cost of the first turn between the two?
5. `⚠HANDOFF 09:12 ·0f ·0c ·?s`: is the HANDOFF up to date?

<details><summary>Answers</summary>

1. That alone does not settle it, but `⚠` says "missing or unreadable". A new session does
   carry the time; if it persists, re-capture the payload (`statusline-internals.md`).
2. Not with the kit's thresholds: 412k is past `context-red`'s 300k. If it is green, someone moved
   the number with `CC_CTX_RED_K`; an unreadable `thresholds.json` would leave it uncoloured and
   say `⚠ umbrales`.
3. `⚡ enfriando · 3m` in amber, because 3 ≤ `cache-cooling` (5), and the hint suggests a short turn
   or a `/handoff`.
4. The first turn rewrites the context either way, but after `/clear` it rewrites a far smaller
   one. At 380k (red band) the right move is `/handoff`, then `/clear`.
5. Unknown: `?s` is "could not count the sessions", not zero. That is why it is not `✓HANDOFF`.

</details>
