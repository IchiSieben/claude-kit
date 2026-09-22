---
name: handoff
description: Write or update HANDOFF.md, the session memory file, before compacting, before ending, or when context reaches the red band of rules/thresholds.json (context-red, 300k). Captures goal, state, decisions, what failed, and next steps so a fresh session can continue without re-exploring.
disable-model-invocation: true
allowed-tools: Read Write Edit Bash(git *)
---

# Handoff

Update `HANDOFF.md` at the repo root (create it if missing). Keep it under 120 lines; older detail goes into `docs/handoffs/YYYY-MM-DD.md` if worth keeping.

Structure (keep these exact headings):

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

Rules:
- Facts only. No narrative. Anything derivable from code or git log stays out.
- "IN PROGRESS" must let someone continue without reading the conversation.
- After writing, print `git status --short` and remind me to commit HANDOFF.md if the project tracks it.
