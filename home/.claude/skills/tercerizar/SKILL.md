---
name: tercerizar
description: Write SPEC.md, TASK.md and (if absent) AGENTS.md into a target repo from the claude-kit templates, so Antigravity's Agent Manager can execute the task headless. Use before handing any implementation work to Antigravity.
argument-hint: [repo-path] [task-name]
---

# Tercerizar: $ARGUMENTS

Parse `$ARGUMENTS` as `<repo-path> <task-name>`. If either is missing, ask for it — do not guess a task name.

## Refuse first

Before touching anything, check every path component of `<repo-path>` (case-insensitive)
against the `KIT_PROTECTED_PATHS` extended regex (set it in the `env` block of `settings.json`; unset means nothing is protected). If any component matches, refuse and say exactly why: this protocol
is file-based and hands the repo to an external tool (Antigravity/Gemini), and employer or client
material must never be pointed at an external tool per the repo's security constraints.
Do not proceed, do not ask for confirmation to override.

## Then

1. Resolve the templates at `claude-kit/templates/` (this repo, sibling
   to your repos). If that directory is missing — e.g. this
   is running on a machine where only `~/.claude` was synced, not the claude-kit repo itself,
   since templates are not part of the `sync-to-home.sh` mirror — say so and stop.
2. Copy `SPEC.md` and `TASK.md` into `<repo-path>` as `SPEC-<task-name>.md` and
   `TASK-<task-name>.md`, filling in `<task-name>` and `ag/<task-name>` in both. Fill in
   whatever inputs/outputs/files-allowed you can infer from the repo; leave the rest as
   `<fill in>` rather than inventing scope.
3. If `<repo-path>/AGENTS.md` does not already exist, copy `templates/AGENTS.md` there and
   fill in the stack/commands section from the repo's own README or package manifest.
4. Print exactly this, with the real values substituted, for pasting into Antigravity's
   Agent Manager:

   > Read AGENTS.md and TASK-<task-name>.md. Implement. Run the tests. Commit on branch
   > ag/<task-name>. Do not touch files outside TASK.

Do not open Antigravity yourself, do not run `agy` in write mode. This skill only prepares
the contract; the owner runs it.
