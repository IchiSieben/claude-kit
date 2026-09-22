---
name: kit-update
description: Pull claude-kit, mirror it into ~/.claude, verify it landed, remind to restart. Run this on any machine after a kit change was pushed from another one.
disable-model-invocation: true
allowed-tools: Bash(git *) Bash(./sync-to-home.sh) Bash(./verify.sh) Bash(./kit-update.sh)
---

# kit-update

Run `./kit-update.sh` from the repo root (`claude-kit`).

It does, in order: `git pull --ff-only`, `./sync-to-home.sh`, `./verify.sh`, then prints
`restart Claude Code`. If any step fails, it stops there and does not print that line —
fix the failure first (a `pull --ff-only` conflict means local commits exist and need
rebasing or stashing by hand; a `verify.sh` failure means something didn't land).

CLAUDE.md and settings.json only load at process launch, so the restart is not optional:
nothing from this pull takes effect in an already-running session.
