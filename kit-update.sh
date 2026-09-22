#!/usr/bin/env bash
# One command per machine: pull the repo, mirror it into ~/.claude, verify it landed.
# CLAUDE.md only loads at process launch, so nothing here takes effect until you restart.
set -euo pipefail
cd "$(dirname "$0")"
git pull --ff-only
./sync-to-home.sh
./verify.sh
echo
echo "restart Claude Code"
