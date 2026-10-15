---
name: route
description: Recommend model, effort level and execution mode (main session, subagent, worktree, background) for a described task, with the reason and the prompt-cache cost of the switch. Use before starting work when unsure which model to spend.
argument-hint: [task description]
---

# Route: $ARGUMENTS

Read the two data files first, then classify the task and answer in this exact table, then
one line of reasoning. **Never write a model name, price, context size or effort default from
memory** — every one comes from these files, and the table cites them.

## Sources (read both, every time)

```bash
jq -r '"models.json fetched_at " + .fetched_at, (.models[] | select(.current) | [.id, .tier, .context, .max_output, .price_in, .price_out, (.default_effort // "-"), (.thinking // "-")] | @tsv)' ~/.claude/rules/models.json
jq -r '"routing.json reviewed " + .reviewed, (.lanes | to_entries[] | [.key, .value.model, (.value.effort // "-"), .value.why] | @tsv)' ~/.claude/rules/routing.json
```

- `rules/models.json` is the FACT layer (ids, tier, context, max output, prices per MTok, default
  effort), harvested weekly by `tools/model-intel.py` from the docs. No LLM wrote it.
- `rules/routing.json` is the JUDGEMENT layer (lane -> model family + effort + why), edited by a
  human after each catalogue change.
- Resolve a lane's family (`opus`) to the id with `"current": true` and that `family` in models.json.
- If either file is missing or does not parse, say so and stop. Do not fall back to a remembered model.
- If `fetched_at` is older than 14 days, or `reviewed` is older than the last `## ` entry in
  `docs/model-intel-log.md` (when that log exists) that is not "no change", say the routing may
  be stale. Refresh the facts with `python tools/model-intel.py`; the lanes are yours to edit.

| Dimension | Value |
|---|---|
| Type | mechanical / feature / debug / architecture / research / review / prose |
| Lane | a key of `routing.json` `lanes` |
| Model | family from the lane -> current id from `models.json` |
| Effort | the lane's effort (`-` = model default, which `models.json` `default_effort` states) |
| Where | main session / subagent / new session / worktree / `claude -p` batch |
| Cache cost | none / full re-read of this conversation |
| Needs SPEC.md? | yes / no |
| Needs plan mode? | yes / no |
| External review after? | yes (Codex or Antigravity, rubric) / no |
| Source | `rules/routing.json` lanes.<lane> (reviewed <date>) + `rules/models.json` (fetched_at <date>) |

## Routing rules (cheap-first cascade, escalate on failure)
Task type -> lane. The model and effort are whatever that lane says today.
- trivial (search, list, count, extract): lane `mecanico`.
- mechanical (rename, format, boilerplate, tests for an existing spec): lane `operario`, subagent if read-heavy.
- prose (README, commit, report, translation): lane `redactor`.
- feature in known code, <=3 files: lane `session-default` in the main session; lane `operario`
  if the pattern already exists in the repo.
- debug with unclear cause: lane `profundo`; start from a reproduction command; never reason more
  than two turns without running something.
- architecture, data model, security boundary, long autonomous run: lane `session-default`, plan
  mode, SPEC.md first; lane `profundo` as a subagent when a trade-off stays open.
- research / codebase exploration: lane `investigador` (or the Explore subagent) — returns paths
  and summaries, keeps the main context clean.
- review: lane `reviewer`, and the reviewer's tier must be at least the author's (tier order from
  models.json: fast < balanced < flagship < frontier). If the author is already at the top tier:
  tests plus an external CLI review; self-review by the same model adds ~nothing.

## THE CACHE RULE (read before recommending a model change)
Each model has its own prompt cache, and on most models so does each effort level. Switching either mid-session makes the next request re-read the whole conversation with no cache hits. Cache reads bill at roughly 10% of standard input, so a switch deep into a long session is the single most expensive keystroke available.

Therefore:
- **Never recommend switching the session model to get a review.** Spawn the `reviewer` subagent instead: a subagent runs its own conversation with its own cache and leaves the parent's prefix untouched.
- Pick model and effort at the TOP of a session. If the task needs a different model, recommend a **new session**, not a switch.
- Exception worth knowing: on Fable 5.1 with a Claude subscription, changing effort keeps the cache. Effort on Fable is cheap to move; model never is.
- `opusplan` re-switches the model on every plan-mode toggle. Do not recommend it for long sessions.
- A skill or agent whose frontmatter names a different `model` is also a model switch for that turn — worth it for a one-shot reviewer, not for a skill you invoke constantly.
- Prefer `/rewind` over `/compact` when abandoning a path: rewind truncates back to a prefix that is already cached; compact builds a new one.

State the cache cost in the table every time. If the recommendation costs a full re-read, say what it buys and offer the new-session alternative.
