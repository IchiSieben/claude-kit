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
#   bash tools/render-grid.sh            (from the kit root; ~7 min on Windows with 8 jobs)
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

# ---- the twelve repos: git state x HANDOFF state -----------------------------------------
GITS=(clean ahead ahead-dirty ahead-new)
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
  if [ "$g" = ahead-dirty ] || [ "$g" = ahead-new ]; then  # two modified tracked files, 1 h old
    printf 'y = 2\n' >> "$r/app.py"; printf -- '- todo\n' >> "$r/notes.md"
    stamp $((NOW-3600)) "$r/app.py"; stamp $((NOW-3600)) "$r/notes.md"
  fi
  if [ "$g" = ahead-new ]; then  # plus one untracked file (?1), 40 min old
    printf 'draft\n' > "$r/scratch.md"; stamp $((NOW-2400)) "$r/scratch.md"
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
for gi in 0 1 2 3; do for hi in 0 1 2; do
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$mi.$ci.$ki.$qi.$gi.$hi" "$mid" "$mname" "$meff" "$ctx" "$warm" "$ttl" "$hit" "$miss" "${cause:--}" \
    "$q5" "$q7" "$TMP/repo-${GITS[$gi]}-${HANDS[$hi]}" >> "$list"
done; done; done; done; done; done

# ---- the session track: one typical 3 h session, every step a real render -------------------
# Unlike the grid, each step has its own clock: elapsed time, cost and diff grow, and its repo is
# built so that the HANDOFF, the commits and the edits have the ages they would have at minute t
# of a session that wrote HANDOFF.md at minute 0. The demo's time slider walks these in order.
# t | ctx | warm | ttl_s | hit | miss | cause | q5 | q7 | cost | added | removed | commits (session
# minutes, '-' none) | pushed up to (minute, '-' none) | dirty | untracked | handoff written (minute)
SESSION=(
  '0|38000|true|3600|1|0|-|6|30|0.14|0|0|-|-|0|0|0'
  '20|96000|true|3540|0.97|0|-|17|31|1.12|124|9|-|-|2|0|0'
  '45|152000|true|3480|0.96|1|-|29|31|2.43|261|22|40|-|0|1|0'
  '70|161000|true|240|0.96|1|-|33|32|2.71|261|22|40|-|0|1|0'
  '90|161000|false|-600|0.96|1|-|33|32|2.71|261|22|40|-|0|1|0'
  '100|214000|true|3570|0.79|4|model_changed|41|32|3.36|305|31|40|-|1|1|0'
  '130|281000|true|3480|0.83|4|-|55|33|4.58|412|47|40,120|-|0|0|0'
  '160|322000|true|3540|0.85|4|-|66|33|5.62|498|60|40,120|-|2|0|0'
  '175|331000|true|3500|0.86|4|-|71|34|6.05|498|60|40,120,174|174|0|0|174'
)
for row in "${SESSION[@]}"; do
  IFS='|' read -r t ctx warm ttl hit miss cause q5 q7 cost add rem commits pushed dirty untr hw <<<"$row"
  r="$TMP/sess-$t"; up="$TMP/sess-$t.git"; at() { echo $((NOW - (t - $1) * 60)); }
  git init -q --bare "$up"; git init -q "$r"
  printf 'print("demo")\n' > "$r/app.py"; printf '# notes\n' > "$r/notes.md"; printf '# HANDOFF\n' > "$r/HANDOFF.md"
  git -C "$r" add -A
  GIT_AUTHOR_DATE=$(gdate $(at -60)) GIT_COMMITTER_DATE=$(gdate $(at -60)) git -C "$r" commit -q -m base
  git -C "$r" remote add origin "$up"; git -C "$r" push -q -u origin main 2>/dev/null
  if [ "$commits" != - ]; then
    for c in ${commits//,/ }; do
      # the commit at the minute HANDOFF.md is rewritten touches only HANDOFF.md (/handoff + commit)
      if [ "$c" = "$hw" ]; then printf '# HANDOFF\nupdated at %s\n' "$c" > "$r/HANDOFF.md"
      else printf 'x%s = 1\n' "$c" >> "$r/app.py"; fi
      git -C "$r" add -A
      GIT_AUTHOR_DATE=$(gdate $(at "$c")) GIT_COMMITTER_DATE=$(gdate $(at "$c")) git -C "$r" commit -q -m "work $c"
      [ "$c" = "$pushed" ] && git -C "$r" push -q origin main 2>/dev/null
    done
  fi
  stamp $(at -60) "$r/app.py"; stamp $(at -60) "$r/notes.md"
  stamp $(at "$hw") "$r/HANDOFF.md"
  if [ "$dirty" -ge 1 ]; then printf 'y = 2\n' >> "$r/app.py"; stamp $(at $((t - 5))) "$r/app.py"; fi
  if [ "$dirty" -ge 2 ]; then printf -- '- todo\n' >> "$r/notes.md"; stamp $(at $((t - 5))) "$r/notes.md"; fi
  if [ "$untr" -ge 1 ]; then printf 'draft\n' > "$r/scratch.md"; stamp $(at 42) "$r/scratch.md"; fi
  (cd "$r" && pwd -W 2>/dev/null || pwd) > "$r.path"
  printf 's%03d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$t" \
    claude-opus-5-5 "Opus 5.5" high "$ctx" "$warm" "$ttl" "$hit" "$miss" "$cause" "$q5" "$q7" "$r" \
    "$cost" "$((t * 60000))" "$add/$rem" >> "$list"
done

render_one() {  # one tab-separated row of $list -> $TMP/out/<key>.ans
  IFS=$'\t' read -r key mid mname meff ctx warm ttl hit miss cause q5 q7 repo cost dur diff <<<"$1"
  # grid cells keep the base fixture's clock; session steps (key s<t>) bring their own
  : "${cost:=3.80}" "${dur:=2700000}" "${diff:=213/15}"
  d=$(cat "$repo.path"); mkdir -p "$TMP/state/$key"   # one state dir per cell: parallel writes
  jq --arg d "$d" --arg mid "$mid" --arg mn "$mname" --arg ef "$meff" --argjson ctx "$ctx" \
     --argjson warm "$warm" --argjson exp $((NOW + ttl)) --argjson hit "$hit" --argjson miss "$miss" \
     --arg cause "$cause" --argjson q5 "$q5" --argjson q7 "$q7" \
     --argjson cost "$cost" --argjson dur "$dur" --argjson add "${diff%/*}" --argjson rem "${diff#*/}" '
     .workspace.current_dir=$d | .workspace.project_dir=$d | .cwd=$d
     | .model={id:$mid, display_name:$mn} | .effort.level=$ef | .session_name="demo"
     | .context_window.current_usage.cache_read_input_tokens=($ctx - 4200)
     | .context_window.total_input_tokens=$ctx
     | .prompt_cache.warm=$warm | .prompt_cache.expires_at=$exp | .prompt_cache.hit_ratio=$hit
     | .prompt_cache.misses=$miss
     | (if $cause == "-" then . else .prompt_cache.last_miss_cause={causes:[$cause]} end)
     | .rate_limits.five_hour.used_percentage=$q5 | .rate_limits.seven_day.used_percentage=$q7
     | .cost.total_cost_usd=$cost | .cost.total_duration_ms=$dur
     | .cost.total_lines_added=$add | .cost.total_lines_removed=$rem' \
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
# sector #16 only exists when rules/thresholds.json cannot be read: one extra render of the
# default cell by a copy of the script with no rules/ next to it
mkdir -p "$TMP/noth"; cp "$SL" "$TMP/noth/statusline.sh"
row=$(grep -m1 '^0\.1\.0\.1\.1\.0'$'\t' "$list"); row="x-noth${row#0.1.0.1.1.0}"
SL="$TMP/noth/statusline.sh" bash -c 'render_one "$1"' _ "$row"
n=$((n + 1))
got=$(ls "$TMP/out" | wc -l)
[ "$got" -eq "$n" ] || { echo "render-grid: only $got of $n cells rendered"; exit 1; }

# ---- assemble grid.json ------------------------------------------------------------------
HASH=$(cat "$SL" "$TH" | tr -d '\r' | sha256sum | cut -c1-64)
mkdir -p docs/demo
"$PY" - "$TMP/out" "$OUT" "$HASH" "$NOW" "$TH" <<'PY'
import json, os, re, sys
src, out, digest, now, th = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]

def legend(path):
    rows = {}
    for line in open(path, encoding="utf-8"):
        m = re.match(r"^\| (\d+) \| (.*) \|\s*$", line.rstrip("\n"))
        if not m: continue
        cells = [c.strip() for c in re.split(r"(?<!\\)\|", m.group(2))]
        if len(cells) >= 4:
            rows[m.group(1)] = {"what": cells[0], "means": cells[1], "source": cells[2], "threshold": cells[3]}
    return rows

lines, index, cells, session, extras = [], {}, {}, [], {}
for name in sorted(os.listdir(src)):
    text = open(os.path.join(src, name), encoding="utf-8").read().rstrip("\n").split("\n")
    ids = []
    for l in text:
        if l not in index: index[l] = len(lines); lines.append(l)
        ids.append(index[l])
    if name.startswith("x-"): extras[name[2:-4]] = ids
    elif name.startswith("s"): session.append({"t": int(name[1:4]), "ids": ids})
    else: cells[name[:-4]] = ids
grid = {
    "about": "Generated by tools/render-grid.sh from home/.claude/statusline.sh. Do not edit.",
    "inputsHash": digest, "renderedAt": now, "cells": cells, "session": session, "extras": extras,
    "lines": lines,
    # the demo's copy names thresholds as {th:<id>} and fills them from here, never from memory
    "thresholds": {t["id"]: {"value": t["condition"]["value"], "param": t.get("param")}
                   for t in json.load(open(th, encoding="utf-8"))["thresholds"]},
    "controls": ["model", "context", "cache", "quota", "git", "handoff"],
    "legend": {"es": legend("docs/statusline.es.md"), "en": legend("docs/statusline.md")},
}
with open(out, "w", encoding="utf-8", newline="\n") as f:
    json.dump(grid, f, ensure_ascii=False, separators=(",", ":"))
    f.write("\n")
# the default cell goes inline into the page, so the bar paints before grid.json is fetched
page = os.path.join(os.path.dirname(out), "index.html")
if os.path.exists(page):
    html = open(page, encoding="utf-8").read()
    key = "0.1.0.1.1.1"
    inline = json.dumps({"key": key, "lines": [lines[i] for i in cells[key]]}, ensure_ascii=False).replace("</", "<\\/")
    html, n = re.subn(r'(<script id="initial" type="application/json">).*?(</script>)',
                      lambda m: m.group(1) + inline + m.group(2), html, flags=re.S)
    if n != 1: sys.exit("render-grid: no <script id=\"initial\"> in " + page)
    with open(page, "w", encoding="utf-8", newline="\n") as f: f.write(html)
print(f"render-grid: {len(cells)} cells + {len(session)} session steps + {len(extras)} extra, {len(lines)} distinct lines, {os.path.getsize(out)//1024} KB -> {out}")
PY
