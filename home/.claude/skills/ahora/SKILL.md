---
name: ahora
description: Where this session stands right now and the one thing to do about it, in three lines - context, 5h quota, cache, session length, unpushed commits and HANDOFF drift, plus the threshold that justifies the advice. Use when unsure whether it is time to /handoff, /clear, push, or just keep going.
disable-model-invocation: true
allowed-tools: Bash(bash *)
---

# Ahora

```!
bash "$HOME/.claude/statusline.sh" --ahora "${CLAUDE_SESSION_ID:-}" 2>/dev/null || bash "$HOME/claude-kit/home/.claude/statusline.sh" --ahora "${CLAUDE_SESSION_ID:-}"
```

Print those three lines **verbatim** and stop. Do not add a fourth line, do not re-explain
the numbers, do not soften the action into an option.

## Why it is a script and not a judgement call

The three lines are deterministic: read the snapshot, compare it with
`rules/thresholds.json`, print the first threshold that fires. That is the layer rule — a
model does not have to DO this, only show it. `statusline.sh --ahora` is the same
evaluator the status line itself uses, so the bar and this skill can never give different
advice.

## What the three lines mean

1. **`ahora:`** the numbers the status line last saw, and how old that snapshot is. The 5h
   quota and the cache ratio exist only in the bar's payload — they are not in the
   transcripts — so an old snapshot means old numbers, and the line says so.
2. **`hacé:`** the action of the highest-priority threshold that is crossed. Exactly one,
   never two.
3. **`por qué:`** which threshold, its condition, and the file it came from.

## Which session it reads

A skill does not receive `$CLAUDE_SESSION_ID` (measured: it is not exported to the shell a
skill runs in), so with no id `--ahora` takes the newest snapshot written **for the current
directory**. Two Claude Code windows open on the same repo can still collide, which is why
line 1 names the session it used whenever it had to choose.

## When the answer is not three numbers

- *no hay snapshot*: the bar has not rendered for this directory yet. Nothing to fix.
- *no puedo leer los umbrales*: `rules/thresholds.json` is missing next to `statusline.sh`.
  `bash kit-update.sh` puts it back. It does **not** fall back to a remembered number.

If you want the *why* behind a threshold rather than its current value: `/manual 7`.
To change one: edit `rules/thresholds.json`, never the script.
