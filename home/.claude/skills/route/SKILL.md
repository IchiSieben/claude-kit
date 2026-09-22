---
name: route
description: Recommend model, effort level and execution mode (main session, subagent, worktree, background) for a described task, with the reason and the prompt-cache cost of the switch. Use before starting work when unsure which model to spend.
argument-hint: [task description]
---

# Route: $ARGUMENTS

Classify the task and answer in this exact table, then one line of reasoning.

| Dimension | Value |
|---|---|
| Type | mechanical / feature / debug / architecture / research / review |
| Model | haiku / sonnet / opus / fable |
| Effort | low / medium / high / xhigh |
| Where | main session / subagent / new session / worktree / `claude -p` batch |
| Cache cost | none / full re-read of this conversation |
| Needs SPEC.md? | yes / no |
| Needs plan mode? | yes / no |
| External review after? | yes (Codex or Antigravity, rubric) / no |

## Routing rules (cheap-first cascade, escalate on failure)
- mechanical (rename, format, boilerplate, tests for an existing spec): **sonnet · medium**, subagent if read-heavy.
- feature in known code, <=3 files: **opus · high**, or sonnet · high if the pattern already exists in the repo.
- debug with unclear cause: **opus · high**, start from a reproduction command; never reason more than two turns without running something.
- architecture, data model, security boundary, long autonomous run: **fable · high/xhigh**, plan mode, SPEC.md first.
- research / codebase exploration: **Explore subagent (sonnet)** — returns paths and summaries, keeps the main context clean.
- review: the reviewer must be at least as strong as the author. Sonnet wrote it -> opus reviews. Opus wrote it -> fable reviews. Fable wrote it -> tests plus an external CLI review; self-review by the same model adds ~nothing.

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
