---
kind: tests
push: false
---
# TASK — kit-demo-gates

Measure the new status-line demo (`docs/demo/`) and record its card clip. Everything repeatable is
code in this repo (`tools/lane.sh` → `docs/tapes/demo-gates.sh` → `docs/tapes/demo-gates.mjs`);
your job is to trigger it, read its output and report truthfully.

## How you run things
Your only Bash is the verification command from the preamble: `bash tools/lane.sh`, exactly.

1. Write the file `.enjambre-lane` with the single word `demo`.
2. Run `bash tools/lane.sh` with the Bash tool's timeout set to 600000. The first call spends
   minutes in `npm install` and `playwright install chromium`. The lane runs detached: each call
   waits up to 100 s, prints the log tail and exits **90 = still running, not a failure**. Call
   `bash tools/lane.sh` again, as often as needed (up to 40 calls), until it prints
   `demo-gates.sh: finished, exit N`.
3. Exit 22 means a gate failed but the report and captures were still written: that is a valid
   result to report, not something to fix.

Do not edit any script, page or setting to make a gate pass. Never a second attempt.

## Files you may touch
- `.enjambre-lane` (gitignored)
- the outputs the lane writes: `evidence/demo-v2/*`, `docs/media/demo-preview.mp4`,
  `docs/media/demo-preview.webm`, `docs/media/demo-poster.webp`

## Done criteria
- [ ] `demo-gates.sh: finished, exit 0` (or 22 with the report written)
- [ ] `evidence/demo-v2/GATES.md` exists with the Lighthouse, axe and flicker lines
- [ ] `docs/media/demo-preview.{mp4,webm}` each <= 1572864 bytes, poster <= 122880 bytes

## Report back
- The final exit, the whole of `evidence/demo-v2/GATES.md`, the encoder lines and the sizes table.
