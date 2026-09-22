# Context hygiene (always loaded)

- Working band: absolute tokens, from `rules/thresholds.json` — below `context-amber` (150k) keep going; at `context-red` (300k) propose /handoff and then /clear. /compact only when this thread must continue. Percentage of the window is NOT the rule: 60% of 1M is twice the red band.
- Milestone compaction beats emergency compaction: after plan approval, after tests pass, before a new unrelated task.
- Never paste full logs, full datasets or full HTML into context. Summarize to <=20 lines with the exact lines that matter.
- One task per session. Unrelated question: tell me to use /btw or /clear.
- Prefer `Explore` subagent for "find where X is handled"; it returns paths and line numbers, not file dumps.
