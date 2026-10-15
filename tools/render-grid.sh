#!/usr/bin/env bash
# tools/render-grid.sh — pre-render the status line for every combination of the demo's controls.
#
# The demo (docs/demo/index.html) must never diverge from the bar, so it does not port
# statusline.sh to JavaScript. This script pipes one generated fixture per combination into the
# REAL home/.claude/statusline.sh and stores the ANSI output in docs/demo/grid.json, together with
# the legend rows of docs/statusline{,.es}.md and a hash of the two files that decide the output
# (statusline.sh + rules/thresholds.json). verify.sh compares that hash: change the bar, and the
# check stays red until this script runs again.
#
#   bash tools/render-grid.sh            (from the kit root; ~2 min on Windows with 8 jobs)
#   JOBS=4 bash tools/render-grid.sh
#
# Requires: bash, jq, git, python3 (or python). Nothing here reads a real session or repo:
# the git and HANDOFF states come from nine throwaway repos built in a temp directory.
set -euo pipefail
cd "$(dirname "$0")/.."
SL=home/.claude/statusline.sh
TH=home/.claude/rules/thresholds.json
OUT=docs/demo/grid.json
JOBS=${JOBS:-8}
PY=""; for p in python3 python; do command -v "$p" >/dev/null && "$p" -c '' 2>/dev/null && { PY=$p; break; }; done
[ -n "$PY" ] || { echo "render-grid: python3 not found"; exit 1; }

NOW=$(date +%s)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
FAKEHOME="$TMP/home"; mkdir -p "$FAKEHOME/.claude/logs"; : > "$FAKEHOME/.claude/logs/events.jsonl"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$TMP/gitconfig"
printf '[user]\n\tname = kit\n\temail = kit@example.invalid\n[core]\n\tautocrlf = false\n[init]\n\tdefaultBranch = main\n' > "$GIT_CONFIG_GLOBAL"

stamp() {  # stamp <epoch> <file>: GNU touch, then BSD touch (macOS)
  touch -d "@$1" "$2" 2>/dev/null || touch -t "$(date -r "$1" +%Y%m%d%H%M.%S)" "$2"
}
gdate() { printf '@%s +0000' "$1"; }

# ---- the nine repos: git state x HANDOFF state -------------------------------------------
GITS=(clean ahead ahead-dirty)
HANDS=(fresh old none)
for g in "${GITS[@]}"; do for h in "${HANDS[@]}"; do
  r="$TMP/repo-$g-$h"; up="$TMP/up-$g-$h.git"
  git init -q --bare "$up"; git init -q "$r"
  printf 'print("demo")\n' > "$r/app.py"; printf '# notes\n' > "$r/notes.md"
  [ "$h" != none ] && printf '# HANDOFF\n\nstate: demo\n' > "$r/HANDOFF.md"
  git -C "$r" add -A
  GIT_AUTHOR_DATE=$(gdate $((NOW-28800))) GIT_COMMITTER_DATE=$(gdate $((NOW-28800))) \
    git -C "$r" commit -q -m base
  git -C "$r" remote add origin "$up"; git -C "$r" push -q -u origin main 2>/dev/null
  if [ "$g" != clean ]; then   # one unpushed commit, 3 h old (past the 2 h `unpushed` param)
    printf 'x = 1\n' >> "$r/app.py"; git -C "$r" add app.py
    GIT_AUTHOR_DATE=$(gdate $((NOW-10800))) GIT_COMMITTER_DATE=$(gdate $((NOW-10800))) \
      git -C "$r" commit -q -m work
  fi
  stamp $((NOW-28800)) "$r/app.py"; stamp $((NOW-28800)) "$r/notes.md"
  if [ "$g" = ahead-dirty ]; then  # two modified tracked files, 1 h old
    printf 'y = 2\n' >> "$r/app.py"; printf -- '- todo\n' >> "$r/notes.md"
    stamp $((NOW-3600)) "$r/app.py"; stamp $((NOW-3600)) "$r/notes.md"
  fi
  case $h in fresh) stamp $((NOW-600)) "$r/HANDOFF.md" ;; old) stamp $((NOW-25200)) "$r/HANDOFF.md" ;; esac
  (cd "$r" && pwd -W 2>/dev/null || pwd) > "$r.path"
done; done

# ---- the fixtures ------------------------------------------------------------------------
# control order = key order: model.ctx.cache.quota.git.handoff (indices joined by dots)
MODELS=('claude-opus-5-5|Opus 5.5|high' 'claude-sonnet-5-5|Sonnet 5.5|medium' 'claude-haiku-5-5|Haiku 5.5|low')
CTX=(60000 180000 320000 385000)
CACHE=('true|2520|0.96|0|' 'true|240|0.79|4|' 'false|-600|0.41|9|model_changed')
QUOTA=('20|30' '41|87' '93|97')
BASE=docs/fixtures/1-warm.json
list="$TMP/cells"; : > "$list"
for mi in 0 1 2; do IFS='|' read -r mid mname meff <<<"${MODELS[$mi]}"
for ci in 0 1 2 3; do ctx=${CTX[$ci]}
for ki in 0 1 2; do IFS='|' read -r warm ttl hit miss cause <<<"${CACHE[$ki]}"
for qi in 0 1 2; do IFS='|' read -r q5 q7 <<<"${QUOTA[$qi]}"
for gi in 0 1 2; do for hi in 0 1 2; do
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$mi.$ci.$ki.$qi.$gi.$hi" "$mid" "$mname" "$meff" "$ctx" "$warm" "$ttl" "$hit" "$miss" "${cause:--}" \
    "$q5" "$q7" "$TMP/repo-${GITS[$gi]}-${HANDS[$hi]}" >> "$list"
done; done; done; done; done; done

render_one() {  # one tab-separated row of $list -> $TMP/out/<key>.ans
  IFS=$'\t' read -r key mid mname meff ctx warm ttl hit miss cause q5 q7 repo <<<"$1"
  d=$(cat "$repo.path"); mkdir -p "$TMP/state/$key"   # one state dir per cell: parallel writes
  jq --arg d "$d" --arg mid "$mid" --arg mn "$mname" --arg ef "$meff" --argjson ctx "$ctx" \
     --argjson warm "$warm" --argjson exp $((NOW + ttl)) --argjson hit "$hit" --argjson miss "$miss" \
     --arg cause "$cause" --argjson q5 "$q5" --argjson q7 "$q7" '
     .workspace.current_dir=$d | .workspace.project_dir=$d | .cwd=$d
     | .model={id:$mid, display_name:$mn} | .effort.level=$ef | .session_name="demo"
     | .context_window.current_usage.cache_read_input_tokens=($ctx - 4200)
     | .context_window.total_input_tokens=$ctx
     | .prompt_cache.warm=$warm | .prompt_cache.expires_at=$exp | .prompt_cache.hit_ratio=$hit
     | .prompt_cache.misses=$miss
     | (if $cause == "-" then . else .prompt_cache.last_miss_cause={causes:[$cause]} end)
     | .rate_limits.five_hour.used_percentage=$q5 | .rate_limits.seven_day.used_percentage=$q7' \
     "$BASE" \
  | CC_NOW=$NOW HOME="$FAKEHOME" CC_NODE=mac CC_ENJ_SUMMARY=/nonexistent CC_STATE_DIR="$TMP/state/$key" \
    CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000 CC_BAR_WIDTH=20 bash "$SL" > "$TMP/out/$key.ans"
}
export -f render_one
export NOW TMP FAKEHOME SL BASE
mkdir -p "$TMP/out" "$TMP/state"
n=$(wc -l < "$list")
echo "render-grid: $n cells, $JOBS jobs"
tr '\n' '\0' < "$list" | xargs -0 -P "$JOBS" -I{} bash -c 'render_one "$1"' _ {}
got=$(ls "$TMP/out" | wc -l)
[ "$got" -eq "$n" ] || { echo "render-grid: only $got of $n cells rendered"; exit 1; }

# ---- assemble grid.json ------------------------------------------------------------------
HASH=$(cat "$SL" "$TH" | tr -d '\r' | sha256sum | cut -c1-64)
mkdir -p docs/demo
"$PY" - "$TMP/out" "$OUT" "$HASH" "$NOW" <<'PY'
import json, os, re, sys
src, out, digest, now = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])

def legend(path):
    rows = {}
    for line in open(path, encoding="utf-8"):
        m = re.match(r"^\| (\d+) \| (.*) \|\s*$", line.rstrip("\n"))
        if not m: continue
        cells = [c.strip() for c in re.split(r"(?<!\\)\|", m.group(2))]
        if len(cells) >= 4:
            rows[m.group(1)] = {"what": cells[0], "means": cells[1], "source": cells[2], "threshold": cells[3]}
    return rows

lines, index, cells = [], {}, {}
for name in sorted(os.listdir(src)):
    text = open(os.path.join(src, name), encoding="utf-8").read().rstrip("\n").split("\n")
    ids = []
    for l in text:
        if l not in index: index[l] = len(lines); lines.append(l)
        ids.append(index[l])
    cells[name[:-4]] = ids
grid = {
    "about": "Generated by tools/render-grid.sh from home/.claude/statusline.sh. Do not edit.",
    "inputsHash": digest, "renderedAt": now, "cells": cells, "lines": lines,
    "controls": ["model", "context", "cache", "quota", "git", "handoff"],
    "legend": {"es": legend("docs/statusline.es.md"), "en": legend("docs/statusline.md")},
}
with open(out, "w", encoding="utf-8", newline="\n") as f:
    json.dump(grid, f, ensure_ascii=False, separators=(",", ":"))
    f.write("\n")
print(f"render-grid: {len(cells)} cells, {len(lines)} distinct lines, {os.path.getsize(out)//1024} KB -> {out}")
PY
