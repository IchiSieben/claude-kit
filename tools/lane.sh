#!/usr/bin/env bash
# tools/lane.sh — the one command an enjambre `tests` job may run in this repo (AGENTS.md
# tests-cmd). It dispatches on the single word the agent writes into `.enjambre-lane`
# (gitignored); no file or an unknown word means the default lane.
#
#   verify (default)  bash verify.sh — both suites, the HANDOFF check, the repo checks
#   media             bash docs/tapes/media.sh — record + encode the status-line card media
#                     (detached: exits 90 while it still runs; call again until it finishes)
#   demo              bash docs/tapes/demo-gates.sh — Lighthouse, axe, flicker, screenshots and
#                     the card clip of docs/demo (detached the same way)
set -uo pipefail
cd "$(dirname "$0")/.."
lane=""; [ -f .enjambre-lane ] && lane=$(tr -dc 'a-z' < .enjambre-lane); lane=${lane:-verify}
echo "lane.sh: lane=$lane"
case "$lane" in
  media) exec bash docs/tapes/media.sh ;;
  demo)  exec bash docs/tapes/demo-gates.sh ;;
  *)     exec bash verify.sh ;;
esac
