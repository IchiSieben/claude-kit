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
three sessions), and **re-captured on 2026-10-15 against 2.1.292–2.1.300** (24 renders from
four live sessions; the `prompt_cache` and `context_window` shapes were unchanged, one cold
render included). The 2.1.300 warm render and the 2.1.292 cold one are the sanitised
fixtures `tests/fixtures/capture-2.1.300.json` and `cache-cold.json`. One shape worth knowing:
an idle session can carry `rate_limits.seven_day` with **no** `five_hour` object, which the
bar prints as `5h ⚠` (missing field), not as blank.

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

| Path | Windows + Git Bash | macOS (Apple Silicon) |
|---|---|---|
| Floor: bash startup + the one jq call, no git and no HANDOFF | **~225 ms** | TBD (measure on the Mac) |
| Full render: git status + commits + dirty-file mtimes + sessions | **~476 ms** | TBD (measure on the Mac) |

The Mac column stays empty until it is measured there with the same method; a predicted
number would be exactly the kind of figure this bar exists to refuse.

The original 200 ms target is **not reachable on this machine**: the
floor alone exceeds it before any git work happens. Dropping the `·Nc` and `·Ns` counters
would get to ~310 ms, still over, and would gut the drift feature. See the roadmap in `README.md`.

**2026-10-15: fewer processes, and a load-proof way to measure.** Milliseconds on this
machine depend on what else runs (that afternoon the same render took 0.5–3.4 s with the CPU
at 86–99 %), so the change was measured in what does not move with load: the external
programs one render starts. `tools/bench-statusline.sh` counts them with PATH shims, prints
the `CC_PROF=1` phase marks, and times old and new interleaved.

| One render | Before | After | How |
|---|---|---|---|
| Full path (git + HANDOFF) | 8 + bash | **6 + bash** | sessions counter: one `grep` + bash instead of `grep \| jq -s`; snapshot for /ahora built by bash (`jstr`/`jnum`) instead of a second `jq` |
| Full path, unpushed commits | 10 + bash | **7 + bash** | the oldest unpushed commit is the last line of `git log`, taken by bash: no `\| tail -1` |
| Floor (directory missing) | 4 + bash | **2 + bash** | no `git` when the directory does not exist (`[ -d ]` is a builtin); snapshot without `jq` |

At the measured ~50–65 ms per spawn and ~28 ms per fork, the full path saves two spawns and a
pipe, roughly 130–160 ms per render on a quiet Windows machine (an estimate from those unit
costs). A wall-clock A/B came later that day, `bench-statusline.sh 3 57f0b1e`, old and new
interleaved with the CPU still loaded and only 3 runs each, so read it as a direction, not a
budget:

| Wall clock, median of 3 (Windows, loaded) | Before (`57f0b1e`) | After |
|---|---|---|
| Full path on this repo, with unpushed commits (the 10 → 7 row) | 911 ms | **782 ms** |
| Floor (directory missing) | 437 ms | **321 ms** |

The
bar prints the same bytes (golden tests, plus an old-vs-new comparison on four real repos
with the real event log) and the snapshot parses to the same JSON.

Hypotheses checked, not assumed:
- *"`git status` is the expensive part, cache it N seconds keyed on `.git/index`."* Rejected.
  `git status` on the largest repo here costs ~100 ms against ~45 ms for `git --version`:
  most of it is the spawn, which a cache read would only partly save. And `.git/index` does
  not change when a tracked file is edited or a new file appears, so a cached `●N ?N` would
  be wrong for up to N seconds, which is the kind of number this bar exists to refuse.
- *"One jq call for every field."* Already true for the payload; the second and third jq
  calls were the ones removed above.
- *"Avoid subshells in loops."* Already true: every loop is builtins; the forks are the
  top-level `$(git ...)`, `$(stat ...)`, `$(grep ...)`.

The 200 ms target stays out of reach on Windows: the floor is bash plus one jq, ~225 ms on a
quiet machine, before any git. What remains on the full path is bash, jq, `git status`,
`stat`, `git log`, `grep` and `mv` (atomic snapshot), each one a number on the bar. The honest
target on Windows is therefore "the floor plus one spawn per thing the bar shows"; the Mac
column of the table above is filled in by `tools/bench-statusline.sh` on that machine.

Also since 2026-10-15: `GIT_OPTIONAL_LOCKS=0`. A `git status` killed mid-refresh by the
status-line timeout can leave `.git/index.lock` behind, and the next commit fails.

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

Determinism comes from pinning `CC_NOW`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, `CC_CTX_*`,
`CC_BAR_WIDTH` and `CC_NODE` (to `test`, so a golden blessed on Windows also passes on the
Mac), and from pointing the fixtures' `current_dir` at a path that does not
exist, so git and HANDOFF take their "no data" branch instead of reading this machine.
The drift counters are covered separately by a throwaway git repo the suite builds
itself, with its fake `HOME` **outside** that repo — an `events.jsonl` created inside it
would show up as an untracked file newer than `HANDOFF.md` and poison the counter under
test.

`statusline.sh --selftest` runs the same suite; it only works from the repo copy, since
`~/.claude/` has no `tests/` beside it, and says so rather than failing obscurely.

---

## macOS

**Ported, not yet verified on a Mac.** The code below was written and tested on Windows +
Git Bash only (the guard's re-exec path through a test seam); nothing has run on macOS yet,
and nothing at all on Intel Macs. The target is the same files on both systems. Install the
three things macOS does not ship in a usable version:

```bash
brew install jq bash coreutils
```

- **`bash`** — macOS ships `/bin/bash` **3.2**, the last GPLv2 release, and Apple will not
  update it. The status line needs **4.2** (associative arrays from 4.0, `printf '%(…)T'`
  dates from 4.2). Which `bash` Claude Code's subprocess picks up depends on its PATH, and an
  app launched from the Dock does not inherit your shell's. So `statusline.sh` starts with a
  guard written in 3.2 syntax: on an old bash it `exec`s `/opt/homebrew/bin/bash` (or
  `/usr/local/bin/bash` on Intel) with the same arguments — stdin survives `exec`, so the
  payload arrives intact. If neither exists the bar prints `⚠ bash4` in amber instead of
  crashing (`--drift` prints nothing, so the hooks stay quiet; `--ahora` still answers in 3
  lines). `settings.json` keeps the portable `"bash ~/.claude/statusline.sh"`: whichever bash
  starts it, it lands on bash ≥ 4.2. The hooks need no guard: none uses a bash-4 feature.
- **`jq`** — found on PATH, then the WinGet shim, then `/opt/homebrew/bin/jq`,
  `/usr/local/bin/jq`. The hooks call bare `jq`, so for them it must be on Claude Code's PATH.
- **`coreutils`** — not required by the bar: it detects BSD `stat` (`-f %m`) vs GNU `stat`
  (`-c %Y`) by itself, without a fork. Useful for your own scripts.

`python3` is what `verify.sh` uses on the Mac; it picks the first of `python3`, `python` that
actually runs (on Windows `python3` is the Microsoft Store stub, which exists and fails).

Line 1 of the bar names the machine: `@mac`, `@win` or `@linux`, read from `$OSTYPE` (no
fork). Over Remote-SSH every window looks the same, so this is how you tell them apart.
`CC_NODE` overrides it with a name of your own — but **not** in `settings.json` `env`: `env` is
one of the `PORTABLE` keys the mirror copies to every machine, so every node would get the
same name. Export it in the environment that launches Claude Code on that machine instead.

What verifying it on a Mac means: both test suites under `/bin/bash` (the guard for real) and
under Homebrew bash, `verify.sh`, the Cost column above, and a screenshot of the bar in VS Code.
