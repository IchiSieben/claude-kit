---
name: xreview
description: Cross-model review workflow. "pack" builds a self-contained review request for Codex CLI or Antigravity CLI (diff, spec, rubric); "ingest" critically evaluates their report and turns accepted findings into tasks. Use after a feature is implemented and tests pass.
disable-model-invocation: true
argument-hint: pack | ingest <path-to-report>
allowed-tools: Read Write Bash(git *)
---

# Cross-model review — mode: $0

Evidence: same-model self-review is biased toward approval (Panickssery 2024); a different, at-least-as-strong reviewer with a forced-choice rubric helps — own practice, not yet backed by a paper; a weaker reviewer can cause harmful rewrites, so external reviewers REPORT, they do not edit.

## If $0 == pack
1. Collect: `git diff main...HEAD` (or staged diff), SPEC.md, the test command and its last output.
2. Write `review/REQUEST-<date>.md` containing:
   - Context in <=10 lines (goal, invariants from SPEC.md, what changed).
   - The diff (or file list if >800 lines; then point at files).
   - The rubric below. Instruct the reviewer: **read-only, do not modify files, output a report to `review/REPORT-<tool>-<date>.md`**.
3. Run the external reviewer yourself and save its report. Antigravity's CLI is `agy` and it
   has a headless mode equivalent to `claude -p`:
   ```bash
   agy -p "Read review/REQUEST-<date>.md and follow it. Report findings only; do not edit files." \
       --model gemini-3-1-pro --effort high \
       --output-format json --print-timeout 10m > review/raw-<date>.json
   jq -r '.response' review/raw-<date>.json > review/REPORT-antigravity-<date>.md
   ```
   Model choice:
   - whole-repo or architectural audit -> `gemini-3-1-pro` at high effort (1M context, independent lineage)
   - a bounded diff -> `gemini-3-8-flash-high` (fast, cheap, separate quota pool from Claude)
   - do NOT use Antigravity's Claude models to review Claude-written code: same vendor lineage,
     one generation behind the author, and the scarcest quota there.
   If `agy` is not installed or errors, say so and stop; do not silently fall back to reviewing it yourself.
   Codex alternative: `codex exec --sandbox read-only "Review per review/REQUEST-<date>.md"`

### Rubric (forced choice per dimension, cite file:line, no prose without a location)
| Dimension | Verdict (pass / concern / fail) | Evidence |
| Correctness vs SPEC invariants | | |
| Failure modes not handled (inputs, empty, concurrency, auth) | | |
| Security (injection, secrets, paths, permissions) | | |
| Duplication added / refactor debt | | |
| Tests: what is NOT covered | | |
| One thing you would change first, and why | | |
Report only gaps. Do not praise. Do not invent findings: if a dimension is fine, write "pass — checked X".

## If $0 == ingest
1. Read the report at $1.
2. For each finding: verify it against the code yourself (open the file:line). Classify: **confirmed / not reproducible / disagree (reason)**.
3. Confirmed findings → add to HANDOFF.md "Next steps" with a verification command each. Disagreements → one line each with the reason, so I can arbitrate.
4. Never apply a reviewer's rewrite wholesale. Fix the confirmed gap in the smallest diff.
