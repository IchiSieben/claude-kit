---
name: spec
description: Interview me and write SPEC.md — the contract for a feature or project (goal, inputs, outputs, invariants, out of scope, acceptance tests) before any implementation. Use for any multi-file feature or new project.
disable-model-invocation: true
argument-hint: [feature or project name]
---

# Spec interview → SPEC.md

Target: $ARGUMENTS

Evidence: writing the contract (pre/post-conditions, undefined behavior) before code — own practice, not yet backed by a paper; tests-as-spec raise solve rates (Mathews & Nagappan 2024).

## 1. Interview (use AskUserQuestion, max 3 rounds, batch questions)
Cover only what you cannot infer from the repo:
- Who uses it and what "done" looks like from their side.
- Inputs (sources, formats, volumes), outputs (files, endpoints, dashboards), and where they live.
- Invariants that must never break; what is explicitly OUT of scope.
- Constraints: stack, runtime (cron, hosting, on-prem), data sensitivity, deadline.
- How we will verify: the 3-5 acceptance checks (commands, not prose).

## 2. Write SPEC.md
```markdown
# SPEC — <name>   (v1, <date>)
## Goal
## Users and trigger
## Inputs / Outputs
## Invariants (must always hold)
## Out of scope
## Architecture sketch (3 layers: deterministic code / instructions / model)
## Acceptance checks
- [ ] `<command>` → expected result
## Open questions
```

## 3. Stop
Do not implement. Say: "SPEC.md written — start a fresh session with /kickoff to implement."
