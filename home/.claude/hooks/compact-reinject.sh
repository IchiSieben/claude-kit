#!/usr/bin/env bash
# SessionStart(matcher: compact). Whatever this prints is added to the compacted context.
# Re-anchors the agent: where we are, what is done, what not to redo.
cd "$(jq -r '.cwd' 2>/dev/null || pwd)" 2>/dev/null
echo "=== POST-COMPACT RE-ANCHOR ==="
if [ -f HANDOFF.md ]; then
  echo "--- HANDOFF.md (authoritative state) ---"
  head -80 HANDOFF.md
else
  echo "No HANDOFF.md found. Run /handoff before continuing long work."
fi
echo "--- last commits ---"
git log --oneline -5 2>/dev/null
echo "--- uncommitted ---"
git status --short 2>/dev/null | head -15
echo "Rule: re-read the current step in HANDOFF.md before acting. Do not redo completed steps."
