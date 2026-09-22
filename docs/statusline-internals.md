# Internals: manual, thresholds, hooks and status line

Technical notes carried over from the private repo this kit was built from. The status-line
section is the reference for the bar's design rules, the 2.1.275 payload change, HANDOFF drift,
how to re-capture the payload, measured cost and the tests.

## The manual

`home/.claude/MANUAL.md` is the operating manual: routing lanes, session lifecycle,
HANDOFF, the status-line glossary, delegation, security, cost. It is mirrored to
`~/.claude/MANUAL.md`, so `/manual` works from any repo, not just this one.

The split that matters: **`CLAUDE.md` holds the rules the model must obey; `MANUAL.md`
holds the why and the examples, for a human.** The model never reads `MANUAL.md` at
runtime — it is not imported with `@`, because that would load ~400 lines of Spanish into
every session for something only you read. So nothing the model must *do* may live only
in the manual. If the two disagree, `CLAUDE.md` wins and the manual is stale.

Two properties keep it honest, both enforced by `verify.sh`:

- **Every rule carries a `Fuente:` line** naming the file it came from. A rule with no
  source is invented and must be deleted.
- **`[PENDIENTE]` markers are real decisions nobody has made.** The two that were live —
  the context band and what follows a handoff — were decided on 2026-09-18: the absolute
  band wins (the `~60%` line is gone from `rules/context-hygiene.md`) and `/clear` is the
  default after a handoff, `/compact` only when the thread must continue. Two remain open
  and are marked as such: when `opusplan` applies (§1) and the spending budget (§7).

## Thresholds

`home/.claude/rules/thresholds.json` is the ONE place the kit's numbers live: 5h quota,
the 150k/300k context bands, the cache floor, session length, unpushed commits and the red
HANDOFF-drift band. Each entry carries `id`, `condition`, `priority`, `actions` and
`source`. `statusline.sh`, `hooks/session-drift-warn.sh` and `/ahora` read it; none of them
carries a number, and a missing file makes the bar print `⚠ umbrales` rather than fall back
to a remembered default. To change how the kit reacts, edit that file — not the code.

## Hooks

| Event | Script | What it does |
|---|---|---|
| `SessionStart` (startup/resume/clear) | `session-drift-warn.sh` | Warns **only** when HANDOFF drift is red. Silent otherwise. |
| `PreCompact` | `precompact-draft.sh` | Appends the mechanical facts to `docs/handoffs/<date>-draft.md`. |
| `PostToolUseFailure` (Bash) | `log-tool-failure.sh` | One redacted JSON line per failed command. |

Contract facts these depend on, confirmed before the code was written — and one captured
from a live run rather than documented:

- **`SessionStart` stdout is added to the session context.** That is the only reason the
  drift warning reaches you at all. It costs tokens on every startup, which is why it
  prints nothing unless the drift is red.
- **`PreCompact` stdout goes to the debug log only** — not shown, not injected. So the
  "you still owe the judgment part" notice is written *inside the draft*, not printed.
- **`PreCompact` exit code 2 blocks compaction.** All three hooks always `exit 0`. A
  draft that fails to write must never cost you a compaction.
- **`PostToolUse` fires on success only**; failures arrive as `PostToolUseFailure`. That a
  non-zero Bash exit triggers it is undocumented — it was verified by installing a probe
  hook and running a command that exits 42. The payload carries `tool_input.command`,
  `error` (whose first line is `Exit code N`), `is_interrupt` and `duration_ms`.
  `tool_response` is **null** on failure, so there is no structured exit code; the script
  does not invent one.

The draft collects facts and stops there. It does not write "where we are and why",
because that is the judgment that makes a handoff worth reading, and a plausible
machine-written paragraph in that slot is worse than a blank one — it looks like someone
thought about it. That part stays yours, or `/handoff`'s.

Three details that are easy to get wrong:

- `is_interrupt: true` means **you** stopped the command. That is not a failed command and
  is not logged.
- Commands are **redacted before they touch disk** (`sk-`, `ghp_`, `xox*`, `AKIA`,
  `token=`, `--password`, `Bearer`), then truncated. Truncation alone does not help with a
  secret at character 10. The log lives under `~/.claude/logs/` (git-ignored) and drafts
  are ignored via `docs/handoffs/*-draft.md`, so there are three layers, not one.
- The commit window comes from the `SessionStart` entry in `events.jsonl` matched on
  `session_id`. No match means the window is **unknown**, and the draft says so — it never
  silently falls back to the whole of `git log`.

Drift has exactly **one** definition, `drift_scan` in `statusline.sh`, exposed as
`statusline.sh --drift <dir>` (prints `state hage f c s`). The hook reads that instead of
growing a second copy that could disagree with the bar.

## Status line

`home/.claude/statusline.sh` renders two lines from the JSON that Claude Code writes to
the command's stdin on every render.

**Verified against Claude Code 2.1.274, 2.1.275 and 2.1.276** (35 captured renders,
three sessions). `claude --version` on this machine reported 2.1.276 at the time.

### The rule the script is built around

A missing or unparsable field prints `⚠` in amber — never `0`, never a raw boolean.
"No data" and "the data is zero" must not look alike, because you act on them
differently. A cost that really is `$0.00` still prints `$0.00`.

### What broke in 2.1.275, and why it broke two things at once

2.1.275 dropped `.permission_mode` from the payload. It was field 9 of the 17 the script
read through `@tsv` + `read`. With `IFS=$'\t'` the tab is *IFS whitespace*, so an empty
field **collapses** and every field after it shifts left by one:

```
printf 'a\t\tc\n' | { IFS=$'\t' read -r x y z; ... }   →   x=a  y=c  z=
```

One slot of shift produced both reported symptoms:

- `hit` received `warm` (`true`) and `ttl` received `misses` (`0`) → the literal `❄true%/0`.
- `dir` received the token count → `git -C 110791` failed and `[ -f "110791/HANDOFF.md" ]`
  was false, so the bar said **"sin HANDOFF" on a repo whose handoff had just been
  committed**. It was never a path-resolution bug.

Fixes: `` (unit separator) instead of tab, so empty fields survive; an explicit
sentinel per field instead of `// ""`, because `//` also swallows a legitimate `false`;
and a field-count guard, so a payload with *fewer* fields than expected renders `⚠`
rather than shifting.

`.permission_mode` has no replacement in the payload, so the BYPASS / plan / dontAsk
guard was **removed from the bar** rather than guessed at from `settings.json` (which
holds the default mode, not the live one — a BYPASS indicator that lies is worse than
none). If the field comes back, restore it in the jq program and the `line2` assembly.

Also fixed while in there: the sessions counter (`·Ns`) called `jq` **without `-n`**, so
jq waited on a stdin the script had already consumed, read EOF and printed nothing. That
counter had been silently reporting `0` since it was written.

### HANDOFF drift

`✓HANDOFF` only when nothing moved after it was written. Otherwise
`⚠HANDOFF 3h ·12f ·2c ·1s`: hours since its mtime, dirty files newer than it, commits
since its mtime, and sessions started for this project since (from
`~/.claude/logs/events.jsonl`). Red at `>20f` or `>=2s`.

Two rules that are easy to get wrong:

- **A commit whose only change is `HANDOFF.md` does not count as a commit after it.**
  Committing a handoff does not touch the file's mtime, so without this the bar goes
  stale the instant you save one — which is exactly when it is freshest.
- **Any counter that cannot be computed shows `?`, never `0`, and never downgrades to
  "sin HANDOFF".** "sin HANDOFF" means the file is genuinely absent.

Known limit: `git log --name-only` prints no file list for a merge commit unless given
`-m`, so a merge landing after the handoff is not counted in `·Nc`. Left as is — these
are single-author repos where merges are rare — but it is a blind spot, not an oversight.

### Re-capturing the payload when Claude Code changes it again

Do not guess field names. Capture a real sample:

1. Wrap the command. Create `~/.claude/statusline-capture.sh`:

   ```bash
   #!/usr/bin/env bash
   tee -a "$HOME/.claude/statusline-sample.jsonl" | bash "$HOME/.claude/statusline.sh"
   ```

   Back up `~/.claude/settings.json` **byte-for-byte** first (`cp`, so you can restore by
   copying back rather than re-editing), then point `statusLine.command` at the wrapper:

   ```json
   "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-capture.sh", "padding": 0 }
   ```

   Claude Code picks the change up live — no restart needed. A separate wrapper file
   beats an inline `sh -c '...'`: no quoting games with whatever shell spawns the
   command on Windows.

2. Let it render. Open a session in a directory that has a `HANDOFF.md` and a git repo,
   so the sample exercises those branches. `tee -a` appends, so the first renders are a
   fresh session and later ones a working one. A couple of minutes is plenty.

3. Map it. The file is concatenated JSON objects — `jq -s` reads it directly. Print the
   union of key paths across *all* renders, not just the last: fields such as
   `prompt_cache` and `context_window.current_usage` are absent or null at startup and
   present afterwards, and that difference is the thing worth knowing.

4. Update `tests/fixtures/` from the new sample and **sanitise**: no real paths, project
   or repo names, session ids or transcript paths. Then `BLESS=1 bash
   tests/statusline_test.sh` to re-bless the golden files, and read the diff before
   trusting it.

5. Undo the capture: restore `settings.json` from the byte-exact backup, delete
   `~/.claude/statusline-capture.sh` and `~/.claude/statusline-sample.jsonl` (it contains
   real paths and session ids), and update the verified-version line above.

### Cost

On this machine (Windows + Git Bash) a process spawn costs ~50–65 ms and a bash `fork`
for command substitution ~28 ms, which dominates everything else.

| Path | Measured |
|---|---|
| Floor: bash startup + the one jq call, no git and no HANDOFF | **~225 ms** |
| Full render: git status + commits + dirty-file mtimes + sessions | **~476 ms** |

The original 200 ms target is **not reachable on this machine**: the
floor alone exceeds it before any git work happens. Dropping the `·Nc` and `·Ns` counters
would get to ~310 ms, still over, and would gut the drift feature. See the roadmap in `README.md`.

What was already done for speed: one jq call for every payload field (not thirteen);
`printf -v` instead of `x=$(printf ...)`; the `read` builtin instead of `$(cat)` to slurp
stdin; a here-string instead of `printf | jq`; `grep` before `jq` on the event log (220 ms
of pure-bash scanning → 78 ms, and flat as the log grows); one `stat` call for
`HANDOFF.md` and every dirty file together; and bash pattern matching instead of
`awk`/`grep`/`wc` to parse `git status --porcelain=v2`.

### Tests

`tests/fixtures/*.json` are sanitised real captures: a fresh session (`current_usage`
null, `prompt_cache` absent, no `session_name`), a long session, a payload with fields
missing or wrongly typed, and a payload of an entirely unknown shape. `tests/expected/`
holds the golden output.

Determinism comes from pinning `CC_NOW`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, `CC_CTX_*`
and `CC_BAR_WIDTH`, and from pointing the fixtures' `current_dir` at a path that does not
exist, so git and HANDOFF take their "no data" branch instead of reading this machine.
The drift counters are covered separately by a throwaway git repo the suite builds
itself, with its fake `HOME` **outside** that repo — an `events.jsonl` created inside it
would show up as an untracked file newer than `HANDOFF.md` and poison the counter under
test.

`statusline.sh --selftest` runs the same suite; it only works from the repo copy, since
`~/.claude/` has no `tests/` beside it, and says so rather than failing obscurely.
