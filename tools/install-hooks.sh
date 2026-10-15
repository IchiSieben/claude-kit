#!/usr/bin/env bash
# tools/install-hooks.sh [repo-dir] — install the kit's git hooks into a repo (default: this one).
#
# Copies templates/githooks/pre-push to <repo>/.githooks/pre-push and points
# core.hooksPath at .githooks. The hook runs the repo's `bash verify.sh` before every push
# and refuses the push if it fails. Commit <repo>/.githooks/ so every clone carries it;
# core.hooksPath is local config, so each clone runs this script once.
#
# Never overwrites: an existing .githooks/pre-push that differs from the template, or a
# core.hooksPath already pointing elsewhere, stops the install with a message.
set -euo pipefail
kit=$(cd "$(dirname "$0")/.." && pwd)
src="$kit/templates/githooks/pre-push"
repo=$(cd "${1:-$kit}" && git rev-parse --show-toplevel)
dst="$repo/.githooks/pre-push"

[ -f "$src" ] || { echo "install-hooks: missing template $src" >&2; exit 1; }
if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
  echo "install-hooks: $dst exists and differs from the template; merge it by hand" >&2
  exit 1
fi
current=$(git -C "$repo" config --get core.hooksPath || true)
if [ -n "$current" ] && [ "$current" != ".githooks" ]; then
  echo "install-hooks: core.hooksPath is already '$current' in $repo; not changing it" >&2
  exit 1
fi
mkdir -p "$repo/.githooks"
[ -f "$dst" ] || cp "$src" "$dst"
chmod +x "$dst"
git -C "$repo" config core.hooksPath .githooks
# The exec bit must reach the index too, or a clone on macOS/Linux ignores the hook.
if git -C "$repo" ls-files --error-unmatch .githooks/pre-push > /dev/null 2>&1; then
  git -C "$repo" update-index --chmod=+x .githooks/pre-push
fi
echo "install-hooks: pre-push installed in $repo (core.hooksPath=.githooks)"
[ -f "$repo/verify.sh" ] || echo "install-hooks: note: $repo has no verify.sh yet; the hook lets pushes through until it does"
