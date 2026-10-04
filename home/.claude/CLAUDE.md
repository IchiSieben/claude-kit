# Master instructions (user scope)
<!-- Keep under 72 lines (70 until 2026-10-04, 60 until 2026-09-18; raised for safety rules, never trimmed to fit). The cap is a CONTEXT BUDGET, not a style rule: this file is re-read every session. Shrink it by cutting prose — the why lives in MANUAL.md — never by cutting a rule. Every rule here must trace to a repeated failure. Audit monthly with /doctor. -->
<!-- The WHY behind every rule below, with examples and open questions: MANUAL.md — `/manual`, `/manual <1-7>`. Rules live HERE; if the two disagree, this file wins and the manual is stale. -->

## Language
- Think, code, name files and write config in English (cheaper tokens). Reply to me in Spanish.
- Deliverables for a Spanish-speaking audience: write them directly in Spanish, never draft in English and translate.

<!-- effort-routing:start -->
## Routing: the layer first, then the lane

**The layer.** Deterministic and repeatable -> code that runs without a model.
Judgment, glue and variable inputs -> instructions. Ask: "does a model have to DO
this, or only ORCHESTRATE it?"

**The lane.** Once a model is warranted:

| Lane | Delegate to | When |
|---|---|---|
| Trivial | `mecanico` (haiku) | Search, list, read logs, extract, count, rename |
| Mechanical | `operario` (sonnet, low) | The decision is made; it only needs writing |
| Prose | `redactor` (sonnet, medium) | READMEs, commits, reports, TDRs, translations |
| Recon | `investigador` (sonnet, medium) | Before touching a repo I do not know |
| Ambiguous | `profundo` (opus, xhigh) | Root cause unclear, real architectural trade-offs |

1. **Recon first.** More than 3-4 files to read: delegate to `investigador`
   instead of reading them in this thread. Only the summary comes back.
2. **The main thread decides, subagents execute.** I settle the what and the how;
   the writing is delegated.
3. **`profundo` is earned, not assumed.** The trigger is ambiguity, not size. A
   20-file refactor with the pattern already defined is `operario`.
4. **Do not delegate what is already in context.** Handing a file you have already
   read to a subagent makes it more expensive, not cheaper.
5. More reasoning in this same thread: `ultrathink`, rather than raising the
   session level.
6. **Never switch the session model to get a review.** Reviewer >= author, but
   switching mid-session invalidates the prompt cache; spawn `reviewer` instead.
<!-- effort-routing:end -->

## Working loop
- Before any non-trivial edit: state the plan in <=8 lines. If it touches more than
  3 files, a schema, auth or money, wait for my OK.
- Verify before claiming done: run the test, build or script that proves it.
  Never "should work".
- If I correct you twice on the same thing, stop and ask me to /clear with a better
  prompt. There is no third attempt.
- Small diffs. Do not refactor or dedupe what I did not ask about; propose it separately.
- Never stop a process by name (`Stop-Process`/`taskkill`/`pkill`) — kill by the PID the
  tool that started it gave you. Never touch processes you did not launch.
- Recursive delete (`rm -r`, `rm -rf`, `del /s`, `Remove-Item -Recurse`) only inside the repo or
  a scratch dir created THIS session. Before it: list the full contents and show me; anything
  you did not create, do not delete — ask. Prefer moving to `_papelera_claude/`.
- Never redirect a background process's stdout if you need its log later — read the log file it writes.

## Status line: propose the action, do not wait to be asked
<!-- Values, order and wording: rules/thresholds.json — never a number here. `/ahora` prints the live one, `/manual 7` the why. -->
| Signal the bar shows, highest priority first | What I propose, unprompted |
|---|---|
| 5h quota past its threshold | stop here, or drop to the `sonnet` lane |
| context in the red band | `/handoff` FIRST, then `/clear` — `/compact` only if this thread must continue |
| cache hit rate under its floor | name the cause; do not switch model or effort mid-session |
| session past 8h and above the amber band | `/handoff`, then `/clear` |
| commits ahead of upstream | `git push` |
| `⚠ umbrales` | thresholds file unreadable: say so, never fall back to a remembered number |

## State files
- `HANDOFF.md` at the repo root is the session memory. Update it with /handoff before
  closing or compacting, and re-read it after any compaction before continuing.
- `SPEC.md` is the contract: inputs, outputs, invariants, out-of-scope. Do not
  implement a multi-file feature without one.
