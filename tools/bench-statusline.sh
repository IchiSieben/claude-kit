#!/usr/bin/env bash
# tools/bench-statusline.sh — how much one render of home/.claude/statusline.sh costs.
#
#   bash tools/bench-statusline.sh [runs] [baseline-rev]
#
# Three measurements, from the most to the least load-proof:
#   1. processes: which external programs one render runs (PATH shims log each call). This
#      number does not move with machine load, so it is the one to compare across changes.
#   2. phases: CC_PROF=1 marks (statusline.sh prints `prof <phase> <epoch.us>` on stderr),
#      median per phase over the runs.
#   3. wall time: median and minimum of `runs` renders. With a baseline rev, the old and new
#      scripts run interleaved, so a load spike hits both alike.
# Payloads: the 2.1.300 capture pointed at this repo (git + HANDOFF.md, the full path) and at
# a directory that does not exist (the floor: bash + one jq, no git).
# Needs bash >= 5 (EPOCHREALTIME) and jq. Writes only under a mktemp dir; nothing else.
set -uo pipefail
cd "$(dirname "$0")/.."
runs=${1:-15} base=${2:-}
SL=home/.claude/statusline.sh
[ -n "${EPOCHREALTIME:-}" ] || { echo "bench-statusline: needs bash >= 5 (EPOCHREALTIME)"; exit 2; }
command -v jq >/dev/null || { echo "bench-statusline: needs jq"; exit 2; }
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT

repo=$PWD
jq --arg d "$repo" '.cwd=$d | .workspace.current_dir=$d | .workspace.project_dir=$d' \
  tests/fixtures/capture-2.1.300.json > "$T/full.json"
jq --arg d "$T/no-such-dir" '.cwd=$d | .workspace.current_dir=$d | .workspace.project_dir=$d' \
  tests/fixtures/capture-2.1.300.json > "$T/floor.json"
if [ -n "$base" ]; then
  mkdir -p "$T/base/rules"
  git show "$base:$SL" > "$T/base/statusline.sh" || { echo "bench-statusline: no $SL at $base"; exit 2; }
  cp home/.claude/rules/thresholds.json "$T/base/rules/"
fi
# Snapshots go to the temp dir, not to ~/.claude/state.
export CC_STATE_DIR="$T/state"
mkdir -p "$CC_STATE_DIR"            # or the first counted render also runs `mkdir`

ms() { local a=$1 b=$2; echo $(( (${b/./} - ${a/./}) / 1000 )); }
stats() { printf '%s\n' "$@" | sort -n | awk '{a[NR]=$1} END {printf "median %4d ms  min %4d ms  (n=%d)", a[int((NR+1)/2)], a[1], NR}'; }
render() { local a b; a=$EPOCHREALTIME; bash "$1" < "$2" >/dev/null 2>&1; b=$EPOCHREALTIME; ms "$a" "$b"; }

count() {                           # count <statusline> <payload>
  local sh="$T/shims" log="$T/calls.log" t real
  mkdir -p "$sh"; : > "$log"
  for t in git jq stat grep mv tail head mkdir rm date cat sed awk wc tr dirname uname hostname; do
    real=$(command -v "$t") || continue
    printf '#!/bin/sh\necho %s >> "%s"\nexec "%s" "$@"\n' "$t" "$log" "$real" > "$sh/$t"; chmod +x "$sh/$t"
  done
  PATH="$sh:$PATH" bash "$1" < "$2" >/dev/null 2>&1
  sort "$log" | uniq -c | awk '{ printf "%s×%s ", $1, $2; n += $1 } END { printf "= %d (+ bash)", n }'
}

echo "== bench-statusline on $(uname -sm), bash $BASH_VERSION, $runs runs"
for p in full floor; do
  echo "-- $p"
  printf '   processes now      : %s\n' "$(count "$SL" "$T/$p.json")"
  [ -n "$base" ] && printf '   processes %-9s: %s\n' "$base" "$(count "$T/base/statusline.sh" "$T/$p.json")"
  now=() old=()
  for ((i=0; i<runs; i++)); do
    if [ -n "$base" ] && (( i % 2 )); then old+=("$(render "$T/base/statusline.sh" "$T/$p.json")"); fi
    now+=("$(render "$SL" "$T/$p.json")")
    if [ -n "$base" ] && ! (( i % 2 )); then old+=("$(render "$T/base/statusline.sh" "$T/$p.json")"); fi
  done
  printf '   wall now           : %s\n' "$(stats "${now[@]}")"
  [ -n "$base" ] && printf '   wall %-14s: %s\n' "$base" "$(stats "${old[@]}")"
done

echo "-- phases (full path, CC_PROF=1, median of $runs)"
for ((i=0; i<runs; i++)); do
  CC_PROF=1 bash "$SL" < "$T/full.json" 2>&1 >/dev/null | awk '$1=="prof" { if (p) printf "%s %d\n", $2, ($3-p)*1000000; p=$3 }'
done | awk '{ v[$1] = v[$1] " " $2; if (!($1 in o)) { o[$1] = ++k; n[k] = $1 } }
  END { for (i = 1; i <= k; i++) { c = split(v[n[i]], a, " "); asort_n(a, c); printf "   %-11s %6.1f ms\n", n[i], a[int((c+1)/2)] / 1000 } }
  function asort_n(a, c,   i, j, t) { for (i = 2; i <= c; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j+1] = a[j]; a[j+1] = t } }'
