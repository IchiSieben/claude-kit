---
name: kickoff
description: Start or resume a project session the same way every time. Reads HANDOFF.md, SPEC.md, git state and tests, then proposes the next step and a model/effort recommendation. Use at the start of every session.
disable-model-invocation: true
argument-hint: [optional focus, e.g. "fix export bug"]
allowed-tools: Read Grep Glob Bash(git *) Bash(ls *) Bash(cat *)
---

# Kickoff protocol

Focus for this session: $ARGUMENTS

## 1. Load state (do not skip)
```!
echo "== HANDOFF =="; [ -f HANDOFF.md ] && head -120 HANDOFF.md || echo "MISSING"
echo "== SPEC =="; [ -f SPEC.md ] && head -60 SPEC.md || echo "MISSING"
echo "== git =="; git log --oneline -8 2>/dev/null; git status --short 2>/dev/null | head -20
echo "== stack =="; ls requirements.txt pyproject.toml package.json Dockerfile docker-compose.yml 2>/dev/null
```

## 2. Classify the session before acting
Answer in <=10 lines:
- What is DONE, IN PROGRESS, BLOCKED (from HANDOFF.md). If HANDOFF.md is missing, say so and offer to create it from git history.
- Is SPEC.md consistent with the code? Name any drift.
- Type of work ahead: `mechanical` | `feature` | `debug` | `architecture` | `research`.
- Recommended model + effort using /route rules (Sonnet·medium for mechanical, Opus·high for feature/debug, Fable·high or xhigh for architecture and long autonomous runs). I decide; do not switch models yourself.

## 3. Propose, then wait
- Propose the first concrete step with its verification command (test, script, curl, screenshot).
- If the step touches >3 files or any schema/auth/money boundary, enter plan mode first.
- Do NOT start editing until I confirm.
