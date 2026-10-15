---
kind: tests
push: false
---
# TASK — kit-bench-1

Measure what one render of the status line costs on this machine, old bar against new. Everything
repeatable is code in this repo (`tools/lane.sh` → `tools/bench-statusline.sh`); your job is to
trigger it, read its output and report truthfully.

## How you run things
Your only Bash is the verification command from the preamble: `bash tools/lane.sh`, exactly.

1. Write the file `.enjambre-lane` with the single word `bench`.
2. Run `bash tools/lane.sh` once, with the Bash tool's timeout set to 600000. It runs 21 renders of
   the current bar and of the bar at `57f0b1e`, interleaved, on two payloads (full path and floor),
   prints a report and writes it to `evidence/bench/<os>-<date>.txt`.

Do not edit any script or setting. Never a second attempt: a failure is a result to report.

## Files you may touch
- `.enjambre-lane` (gitignored)
- the report the lane writes under `evidence/bench/`

## Done criteria
- The lane printed `lane.sh: bench report -> ...` and the report file exists.
- Your final message quotes the report's `processes`, `wall` and `phases` lines verbatim and
  states the exit code. No interpretation beyond that.
