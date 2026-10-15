---
lesson:
  route: code-like-me
  order: 7
  level: 2
---

# Reviewer: a stronger model, a fresh context

## Reviewer >= author, never weaker

A model reviewing its own output shows measurable self-preference bias; a different model
that is at least as strong does not. That is why the `reviewer` agent is pinned to
`opus`/`high` regardless of which model wrote the code, and why cross-model review has a
direction: Claude may review Gemini's code, and Gemini 3.1 Pro (high) may do a second pass
on Claude's code, but Claude models inside Antigravity must never review Claude's own
code — same vendor lineage reviewing itself.

Source: `home/.claude/agents/reviewer.md` (comment above the procedure); `home/.claude/MANUAL.md`
§5 ("Revisor ≥ autor... cadena de revisión cruzada permitida").

## Fresh context, its own cache

`reviewer` is `Read, Grep, Glob, Bash(git *)` only — read-only, it cannot edit files. It runs
in its own subagent context, with its own prompt cache, so spawning it does not touch the
parent session's cache the way switching the session model with `/model` would. That is the
concrete reason routing rule 6 (`docs/routing.md`) says never to change the session model
to get a review.

Source: `home/.claude/agents/reviewer.md` frontmatter (`tools:`, description); `home/.claude/CLAUDE.md`
§Routing rule 6.

## Why same-model self-review is not a gate

The evidence the kit cites: same-model self-review is biased toward approval (Panickssery
2024). Using a different, at-least-as-strong reviewer with a forced-choice rubric is the
kit's own practice, not yet backed by a paper — see `docs/references.md` for what is verified
and `docs/references-candidates.md` for the search trail on the citation this used to carry.
This is why both `reviewer` and `/xreview` use a rubric with no dimension allowed to be
skipped, rather than open-ended commentary.

Source: `home/.claude/skills/xreview/SKILL.md` (Evidence line).

## `/xreview`: cross-model review, step by step

`xreview` has two modes, invoked as `pack` or `ingest`; it does not auto-trigger from a
description (`disable-model-invocation: true`).

**`pack`:**
1. Collect `git diff main...HEAD` (or the staged diff), `SPEC.md`, the test command and its
   last output.
2. Write `review/REQUEST-<date>.md`: context in <=10 lines, the diff (or a file list if it's
   over 800 lines), and the rubric below. Instruct the external reviewer to be read-only and
   to write its report to `review/REPORT-<tool>-<date>.md`.
3. Run the external reviewer and save its output. For Antigravity's `agy` CLI in headless
   mode: whole-repo/architectural audits use `gemini-3-1-pro` at high effort (1M context,
   independent lineage); a bounded diff uses `gemini-3-8-flash-high` (fast, separate quota
   pool from Claude). Antigravity's Claude models must never review Claude-written code. If
   `agy` is missing or errors, say so and stop — never silently fall back to self-review.
   Codex alternative: `codex exec --sandbox read-only`.

**`ingest <path-to-report>`:**
1. Read the report.
2. Verify each finding against the actual code (open the file:line) and classify it:
   confirmed / not reproducible / disagree (with reason).
3. Confirmed findings go into HANDOFF.md's "Next steps" with a verification command each;
   disagreements get one line each for the owner to arbitrate.
4. Never apply a reviewer's rewrite wholesale — fix the confirmed gap with the smallest
   possible diff.

Source: `home/.claude/skills/xreview/SKILL.md`.

## The rubric (both `reviewer` and `/xreview`)

Forced choice per dimension — pass / concern / fail — with `file:line` evidence, no prose
without a location:

| Dimension |
|---|
| Correctness vs SPEC invariants |
| Failure modes not handled (empty input, concurrency, auth, partial writes) |
| Security (injection, secrets, path traversal, permissions) |
| Duplication added / consolidation or refactor debt skipped |
| What the tests do NOT cover |

`reviewer` additionally reads `SPEC.md` and runs the project's test command, quoting the
last 15 lines, and closes with "Would I merge? yes / no, because <one line>." If a dimension
is fine, the required phrasing is "pass — checked <what>" — findings are never invented to
look thorough, and passes are never padded with praise.

Source: `home/.claude/agents/reviewer.md`; `home/.claude/skills/xreview/SKILL.md` (Rubric).

## `templates/REVIEW.md`

The template a review report is expected to fill: a verdict checkbox (merge as-is / merge
with fixes / send back — does not meet SPEC.md), a Findings list (`file:line` — what's
wrong, why it matters), a Security check line (no secrets, no credentials, no path
traversal, no scope creep beyond the task's allowed files), and, if not merging, a "Sent
back for" list of exactly what to fix.

Source: `templates/REVIEW.md`.

## What the reviewer must NOT do

Report only — never edit files, never fix what it finds, never invent findings to appear
thorough, never praise a passing dimension. Both `home/.claude/agents/reviewer.md` and the
`/xreview` skill state this explicitly, and `/xreview ingest` step 4 extends it: even after
a human decides a finding is confirmed, the fix is applied by hand as the smallest diff —
never by pasting in the reviewer's own rewrite.

Source: `home/.claude/agents/reviewer.md` ("Report only. Do not edit files."); `home/.claude/skills/xreview/SKILL.md`.
