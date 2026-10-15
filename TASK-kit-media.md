---
kind: tests
push: false
---
# TASK — kit-media

Record the claude-kit status line reacting through its five states (caché caliente, enfriando,
fría, contexto en rojo, HANDOFF atrasado) in a real terminal, encode the card media for the
Landing and regenerate the legend PNGs and GIF. Everything repeatable is code in this repo
(`tools/lane.sh` → `docs/tapes/media.sh`); your job is to trigger it, read its output and report
truthfully.

## How you run things
Your only Bash is the verification command from the preamble: `bash tools/lane.sh`, exactly.

1. Write the file `.enjambre-lane` with the single word `media`.
2. Run `bash tools/lane.sh` with the Bash tool's timeout set to 600000. The first call may spend
   minutes in `brew install` (vhs, freeze, a Nerd Font). The lane runs detached: each call waits up
   to 100 s, prints the log tail and exits **90 = still running, not a failure**. Call
   `bash tools/lane.sh` again, as often as needed (up to 40 calls), until it prints
   `media.sh: finished, exit N`.
3. Read the output: the `== sizes` table (bytes, codec, 1280x720, 60 fps, colour tags) and the
   encoder lines (`webm ... crf`, `mp4 x264 crf`, `poster webp q`).

If it finishes with a non-zero exit, read `docs/tapes/out/media.log` and report the failing step
verbatim. Do not edit any script, fixture or setting to make it pass. Never a second attempt.

## Files you may touch
- `.enjambre-lane` (gitignored)
- the outputs the lane writes: `docs/media/statusline-preview.webm`, `docs/media/statusline-preview.mp4`,
  `docs/media/statusline-poster.webp`, `docs/img/statusline-*.png`, `docs/img/statusline-states.gif`

## Done criteria
- [ ] `media.sh: finished, exit 0`
- [ ] webm and mp4 each <= 1572864 bytes, 1280x720, 60 fps; poster <= 122880 bytes
- [ ] the five `docs/img/statusline-<state>.png` and the GIF were rewritten

## Report back
- The final exit, the `== sizes` table, the three encoder lines, and the last 25 log lines.
