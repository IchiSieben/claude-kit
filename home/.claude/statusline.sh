#!/usr/bin/env bash
# Claude Code status line — context in absolute tokens, quality bands, cache health.
#
# Why absolute tokens and not % of window: quality degrades at an absolute size, not a
# proportional one. 366k is a lot of context whether the window is 200k or 1M.
# Why the bar tops out at RED_K: it is a risk gauge, not a fuel gauge.
# The ┋ mark is where auto-compact will fire, so you can see the two limits at once.
#
# THE RULE THIS FILE IS BUILT AROUND: a missing or unparsable field prints ⚠ in amber,
# never 0 and never a raw boolean. "No data" and "the data is zero" must not look alike —
# that is the whole point of a status line you trust at a glance.
#
# EVERY number this bar reacts to lives in rules/thresholds.json, next to this script.
# None of them is written here: a threshold that exists in two places drifts. If that file
# is missing or unreadable the bar says `⚠ umbrales` and stops colouring and hinting —
# a threshold you cannot read is not the same thing as a threshold that is not crossed.
#
# Tunables (env, e.g. in settings.json "env"):
#   CC_CTX_GREEN_K  override the context-amber threshold (default: thresholds.json)
#   CC_CTX_RED_K    override the context-red threshold   (default: thresholds.json)
#   CC_BAR_WIDTH    default 20    characters
#   CC_STATE_DIR    where the /ahora snapshot is written (default ~/.claude/state)
#   CC_NOW          override "now" (epoch seconds) — used by --selftest only
#   CC_NODE         name shown as @<node> instead of mac/win/linux. NOT in settings.json
#                   "env": that key is mirrored to every machine, so all would share it
# Requires jq. Verified against the stdin payload of Claude Code 2.1.274/275/276;
# see README.md ("Status line") for how to re-capture a sample when it changes.

# ---- bash >= 4.2 guard. MUST stay first, and MUST stay bash-3.2 syntax. ----
# macOS ships /bin/bash 3.2 (the last GPLv2 release) and which `bash` Claude Code's subprocess
# finds there depends on PATH. This file needs 4.0 (`declare -A`, `${p,,}`) and 4.2
# (`printf '%(…)T'`), so an old bash re-execs into Homebrew's with the same args; stdin is
# inherited across `exec`, so the payload survives. No forks: on bash >= 4.2 it is one test.
# The exported sentinel stops a second hop: if the "new" bash is old too, we say so and stop.
# CC_TEST_BASH_MAJOR / CC_BASH4_CANDIDATES exist for tests/statusline_test.sh only — they let
# a machine without bash 3.2 prove the re-exec path. The fake major is ignored after the hop.
_cc_major=${BASH_VERSINFO[0]} _cc_minor=${BASH_VERSINFO[1]}
[ -n "${CC_BASH_REEXEC:-}" ] || _cc_major=${CC_TEST_BASH_MAJOR:-$_cc_major}
if [ "$_cc_major" -lt 4 ] || { [ "$_cc_major" -eq 4 ] && [ "$_cc_minor" -lt 2 ]; }; then
  if [ -z "${CC_BASH_REEXEC:-}" ]; then
    export CC_BASH_REEXEC=1
    for _cc_b in ${CC_BASH4_CANDIDATES:-/opt/homebrew/bin/bash /usr/local/bin/bash}; do
      [ -x "$_cc_b" ] && exec "$_cc_b" "${BASH_SOURCE[0]}" "$@"
    done
  fi
  # No bash >= 4.2 anywhere. Say it in the shape each caller expects, never crash.
  case "${1:-}" in
    --drift) ;;                  # the hooks read "nothing" as "no data" and stay quiet
    --ahora) printf '%s\n' "ahora: esta barra necesita bash >= 4.2 y solo encontró ${BASH_VERSION}" \
                           "hacé: brew install bash (queda en /opt/homebrew/bin/bash; la barra lo busca sola)" \
                           "por qué: macOS trae bash 3.2, sin arrays asociativos ni printf de fechas" ;;
    *)       printf '%s\n' $'\033[33m⚠ bash4\033[0m' ;;
  esac
  exit 0
fi
# The sentinel has been read; drop it so nothing this script starts (e.g. --selftest's
# runner, which drives the guard on purpose) inherits "already re-exec'd".
unset _cc_major _cc_minor _cc_b CC_BASH_REEXEC

set -u

# WHY: printf '%.2f' / '%.0f' parse AND print with LC_NUMERIC, so under es_ES "12.3456"
# reads as 12 and prints "$12,00". LC_ALL beats every LC_*, so LC_NUMERIC=C alone loses to
# it, and LC_ALL=C would break the UTF-8 glyphs. Hand LC_ALL's value to LC_CTYPE, drop
# LC_ALL, then pin only the numbers to C. Builtins, no forks.
if [ -n "${LC_ALL:-}" ]; then export LC_CTYPE="$LC_ALL"; unset LC_ALL; fi
export LC_NUMERIC=C

W=${CC_BAR_WIDTH:-20}

# Resolved at parse time, not with `dirname` (a fork): the repo copy reads the repo's
# thresholds and the mirrored copy reads the mirrored ones, so neither can read the other's.
case "${BASH_SOURCE[0]}" in
  */*) TH_FILE="${BASH_SOURCE[0]%/*}/rules/thresholds.json" ;;
  *)   TH_FILE="rules/thresholds.json" ;;
esac
[ -r "$TH_FILE" ] || TH_FILE=""
GREEN_K=-1 RED_K=-1 TH_OK=0
# The metrics the thresholds are measured against. -1 means NOT MEASURED, which never
# matches a condition: the whole point of this bar is that unknown and zero differ.
five_i=-1 used_k=-1 hit_i=-1 cl_m=-1 rt_m=-1 ahead=-1 MD_F=-1 MD_S=-1 fresh=0 CAUSES_TXT=""
HINT_ID="" HINT="" MV=-1

# Real ESC bytes, not "\033" strings: the final printf uses %s, so a backslash inside a
# session name or a Windows path can never be re-interpreted as an escape sequence.
R=$'\033[0m'; B=$'\033[1m'
RED=$'\033[31m'; AMB=$'\033[33m'; GRN=$'\033[32m'; MAG=$'\033[35m'; CYN=$'\033[36m'
WARN="${AMB}⚠${R}"

# Sentinels emitted by the jq program below. They cannot occur in real data.
S=$'\001'   # field missing or of an unexpected type -> render ⚠
E=$'\002'   # parent object is explicitly null -> legitimately no data yet, render nothing

# ---- jq resolution: PATH, then the WinGet link shim, then Homebrew, else bail loud. ----
# Never print an all-zeros line: a broken jq must look broken, not idle.
# Homebrew paths matter because Claude Code launched from the Dock/Finder does not inherit
# the shell's PATH, so /opt/homebrew/bin (Apple Silicon) or /usr/local/bin (Intel) may be
# missing from it even though `jq` works in your terminal.
JQ_BIN=""
if command -v jq >/dev/null 2>&1; then
  JQ_BIN="jq"
elif [ -x "${LOCALAPPDATA:-}/Microsoft/WinGet/Links/jq.exe" ]; then
  JQ_BIN="${LOCALAPPDATA}/Microsoft/WinGet/Links/jq.exe"
elif [ -x /opt/homebrew/bin/jq ]; then
  JQ_BIN=/opt/homebrew/bin/jq
elif [ -x /usr/local/bin/jq ]; then
  JQ_BIN=/usr/local/bin/jq
fi
if [ -z "$JQ_BIN" ]; then
  printf '%s\n' "${RED}⚠ jq${R}"
  exit 0
fi

# ---- stat flavour, decided once, without a fork. ----
# GNU stat (Git Bash, Linux) wants `-c %Y`; BSD stat (macOS) wants `-f %m` and reads `-c`
# as an error. $OSTYPE is a bash variable, so Windows pays nothing for this. On BSD the PATH
# may still put coreutils' gnubin `stat` first, so ask bash's own command hash which file
# `stat` resolves to (BASH_CMDS, filled by `hash`: no fork either) and use the BSD format
# only for the system one.
STAT_FMT=(-c '%Y')
case "${OSTYPE:-}" in
  darwin*|*bsd*)
    hash stat 2>/dev/null
    case "${BASH_CMDS[stat]:-}" in /usr/bin/stat|'') STAT_FMT=(-f '%m') ;; esac ;;
esac

# ---- node: which machine is this bar being drawn on? ----
# Over Remote-SSH the window looks identical on every machine; this says which one runs
# the session. Same mapping as `uname -s` (Darwin, MINGW*/MSYS*/CYGWIN*, Linux) but read
# from $OSTYPE, which bash already holds: no fork. CC_NODE overrides it (a name of your
# own, e.g. "casa", or a fixed value so the golden tests read the same on every OS).
if [ -n "${CC_NODE:-}" ]; then NODE=$CC_NODE
else
  case "${OSTYPE:-}" in
    darwin*)              NODE=mac ;;
    msys*|cygwin*|win*)   NODE=win ;;
    linux*)               NODE=linux ;;
    *)                    NODE=${OSTYPE:-} ;;
  esac
fi

# Serialises rules/thresholds.json into ONE field: thresholds joined by \u001e, the fields of
# each threshold by \u001d. Written once here and reused by --ahora, so the bar and the skill
# can never disagree about what a threshold is. Sorted by priority, so the bar reads the
# order and never the priority number itself.
JQ_TH='(($TH[0] // {}).thresholds // []
        | sort_by(.priority // 999)
        | map([ (.id // ""),
                (if (.hint // false) then "1" else "0" end),
                (.condition.metric // ""),
                (.condition.op // ""),
                ((.condition.value // -1)|tostring),
                (.gate // ""),
                ((.param // "")|tostring),
                (.actions.default // ""),
                (.actions.fresh // ""),
                (.actions.nodata // "") ]
              | join("\u001d"))
        | join("\u001e"))'

# The words of the cache segment, from the same file (`labels`): warm, cooling, cold.
JQ_LABELS='((($TH[0] // {}).labels // {}) as $l
           | [($l["cache-warm"] // ""), ($l["cache-cooling"] // ""), ($l["cache-cold"] // "")]
           | map(if type=="string" then . else "" end) | join("\u001d"))'

# The jq program, kept in a variable so the quoting is written once.
JQ_PROG='
  def S: "\u0001";
  def E: "\u0002";
  def num($v): if ($v|type)=="number"  then ($v|tostring) else S end;
  def txt($v): if ($v|type)=="string" and ($v|length)>0 then $v else S end;
  def bol($v): if ($v|type)=="boolean" then (if $v then "1" else "0" end) else S end;
  def cache($v): if ((.prompt_cache? // null)|type)=="null" then E else $v end;
  def rl($v):    if ((.rate_limits?  // null)|type)=="null" then E else $v end;
  [
    txt(.model.display_name? // null),
    txt(.effort.level? // null),
    num(.context_window.context_window_size? // null),
    num(.cost.total_cost_usd? // null),
    num(.cost.total_duration_ms? // null),
    rl(num(.rate_limits.five_hour.used_percentage? // null)),
    rl(num(.rate_limits.seven_day.used_percentage? // null)),
    txt(.session_name? // null),
    num(.cost.total_lines_added? // null),
    num(.cost.total_lines_removed? // null),
    txt(.workspace.current_dir? // null),
    (if ((.context_window.current_usage? // null)|type)=="object" then
       ([(.context_window.current_usage.input_tokens? // null),
         (.context_window.current_usage.cache_creation_input_tokens? // null),
         (.context_window.current_usage.cache_read_input_tokens? // null)]
        | map(select(type=="number"))
        | if length==0 then S else (add|tostring) end)
     elif ((.context_window.used_percentage? // null)|type)=="number"
      and ((.context_window.context_window_size? // null)|type)=="number" then
       ((.context_window.used_percentage * .context_window.context_window_size / 100)|floor|tostring)
     else S end),
    cache(if ((.prompt_cache.hit_ratio? // null)|type)=="number"
          then (.prompt_cache.hit_ratio*100|floor|tostring) else S end),
    cache(bol(.prompt_cache.warm? // null)),
    cache(txt(.prompt_cache.ttl? // null)),
    cache(num(.prompt_cache.misses? // null)),
    cache(num(.prompt_cache.expires_at? // null)),
    cache(if ((.prompt_cache.last_miss_cause.causes? // null)|type)=="array"
          then (.prompt_cache.last_miss_cause.causes|map(tostring)|join(",")) else E end),
    txt(.session_id? // null),
    '"$JQ_TH"',
    '"$JQ_LABELS"'
  ] | join("\u001f")
'

# ---- thresholds: loaded from rules/thresholds.json, never written here. ----
# The bar knows threshold IDs and metric NAMES. It does not know a single threshold value,
# so changing a number is an edit to the JSON and never to this file.
declare -A TH_HINT TH_METRIC TH_OP TH_VALUE TH_GATE TH_PARAM TH_A TH_AF TH_AN
TH_ORDER=()

# th_load <blob> -> 0 when the file gave us a usable table. The blob arrives pre-sorted by
# priority, so position IS priority and the number itself is never compared.
th_load() {
  local -a rows=(); local row id h m o v g pm a af an
  TH_ORDER=()
  [ -n "${1:-}" ] || return 1
  IFS=$'\036' read -r -a rows <<<"$1"
  for row in "${rows[@]}"; do
    IFS=$'\035' read -r id h m o v g pm a af an <<<"$row"
    [ -n "$id" ] || continue
    TH_HINT[$id]=$h TH_METRIC[$id]=$m TH_OP[$id]=$o TH_VALUE[$id]=$v
    TH_GATE[$id]=$g TH_PARAM[$id]=$pm TH_A[$id]=$a TH_AF[$id]=$af TH_AN[$id]=$an
    TH_ORDER+=("$id")
  done
  # The seven the bar cannot render without. A file that lost one of them is a broken file,
  # not a file that says "no threshold": either way the bar must not invent the number.
  local need
  for need in context-amber context-red cache-cold cache-cooling cache-hit-ok \
              handoff-drift-files handoff-drift-sessions; do
    [ -n "${TH_VALUE[$need]:-}" ] || return 1
  done
  return 0
}

# th_metric <name> -> MV. The ONE place a threshold's metric name meets a measured value.
th_metric() {
  case "$1" in
    five_pct)         MV=$five_i ;;
    context_k)        MV=$used_k ;;
    cache_pct)        MV=$hit_i ;;
    cache_left_min)   MV=$cl_m ;;
    session_min)      MV=$rt_m ;;
    ahead)            MV=$ahead ;;
    handoff_dirty)    MV=$MD_F ;;
    handoff_sessions) MV=$MD_S ;;
    *)                MV=-1 ;;
  esac
}

# th_fires <id> -> 0 when its condition holds right now.
th_fires() {
  # Two statements, not one: bash expands every word of a `local` line BEFORE it assigns
  # any of them, so `local id=$1 v=${TH_VALUE[$id]}` reads $id while it is still unset.
  local id=$1
  local v=${TH_VALUE[$id]:-}
  [ -n "$v" ] || return 1
  th_metric "${TH_METRIC[$id]:-}"
  (( MV < 0 )) && return 1
  case "${TH_OP[$id]:-}" in
    '>=') (( MV >= v )) ;;
    '>')  (( MV >  v )) ;;
    '<=') (( MV <= v )) ;;
    '<')  (( MV <  v )) ;;
    *)    return 1 ;;
  esac
}

# th_pick -> HINT_ID / HINT for the first (= highest priority) threshold that fires.
# ONE hint, never two: a status line is for state, not analysis.
th_pick() {
  HINT_ID="" HINT=""
  local id act n
  for id in "${TH_ORDER[@]}"; do
    [ "${TH_HINT[$id]}" = 1 ] || continue
    th_fires "$id" || continue
    [ -z "${TH_GATE[$id]}" ] || th_fires "${TH_GATE[$id]}" || continue
    th_metric "${TH_METRIC[$id]}"; n=$MV
    act=${TH_A[$id]}
    if (( fresh )) && [ -n "${TH_AF[$id]}" ]; then act=${TH_AF[$id]}; fi
    case "$act" in
      *'{causes}'*) [ -n "$CAUSES_TXT" ] || [ -z "${TH_AN[$id]}" ] || act=${TH_AN[$id]} ;;
    esac
    act=${act//\{n\}/$n}
    act=${act//\{h\}/$(( rt_m / 60 ))}
    act=${act//\{causes\}/$CAUSES_TXT}
    HINT_ID=$id HINT=$act
    return 0
  done
  return 1
}

# ---- HANDOFF drift: stale unless nothing moved after it was written. ----
# Fresh = no dirty file newer than it, no commit since, no session started since.
# Every counter can independently come back "?": a number we could not compute must
# not masquerade as a zero, and a HANDOFF that exists must never read "sin HANDOFF".
#
# This lives in a function, and `--drift` prints it, so the SessionStart hook reuses THIS
# definition instead of growing a second one that can drift from the bar.
# Usage: drift_scan <dir> <dirfs> <have_git> <now> [dirty paths...]
# Sets: D_STATE (none|ok|stale)  D_HAGE  D_F  D_C  D_S  D_FILE
drift_scan() {
  local dir=$1 dirfs=$2 have_git=$3 now=$4; shift 4
  local -a dirty=("$@")
  D_STATE=none D_HAGE="?" D_HTIME="?" D_F="?" D_C="?" D_S="?" D_FILE=""

  local toplevel=""
  if [ -n "$dirfs" ] && [ -f "$dirfs/HANDOFF.md" ]; then
    D_FILE="$dirfs/HANDOFF.md"
  elif (( have_git )); then
    toplevel=$(git -C "$dirfs" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$toplevel" ] && [ -f "$toplevel/HANDOFF.md" ]; then D_FILE="$toplevel/HANDOFF.md"; fi
  fi
  [ -n "$D_FILE" ] || return 0

  local f="?" c="?" s="?" hage="?" htime="?" hm="" statout ln
  local -a mt=() statargs=("$D_FILE")
  local p
  for p in "${dirty[@]}"; do statargs+=("$dirfs/$p"); done
  # One stat call for HANDOFF.md and every dirty file at once (format: STAT_FMT, above).
  if statout=$(stat "${STAT_FMT[@]}" -- "${statargs[@]}" 2>/dev/null); then
    while IFS= read -r ln; do mt+=("${ln%$'\r'}"); done <<<"$statout"
    hm=${mt[0]:-}
  fi
  if [[ $hm =~ ^[0-9]+$ ]]; then
    hage="$(( (now - hm) / 3600 ))h"
    # The bar shows WHEN, not how long ago: it only redraws on session events, so an age
    # freezes ("hace 50 min" for hours). A clock time stays true. Another day: day/month.
    # The visor (it polls) shows the live age. Builtins, no fork.
    local hday nday
    printf -v hday '%(%Y%m%d)T' "$hm"; printf -v nday '%(%Y%m%d)T' "$now"
    if [ "$hday" = "$nday" ]; then printf -v htime '%(%H:%M)T' "$hm"
    else printf -v htime '%(%d/%m %H:%M)T' "$hm"; fi
    if (( have_git )); then
      local k
      f=0
      for ((k=1;k<${#mt[@]};k++)); do
        [[ ${mt[k]} =~ ^[0-9]+$ ]] || continue
        (( mt[k] > hm )) && f=$(( f + 1 ))
      done
      # A dirty file we could not stat means the count is unknown, not zero.
      (( ${#mt[@]} - 1 == ${#dirty[@]} )) || f="?"
      # Commits after the HANDOFF was written. A commit whose only change IS
      # HANDOFF.md is the act of saving it, not work done after it — otherwise the
      # bar goes stale the instant you commit a handoff, which is when it is freshest.
      local logout cts files hset
      if logout=$(git -C "$dirfs" log -n 50 --since="@${hm}" --format=$'\001%ct' --name-only 2>/dev/null); then
        c=0; cts=-1; files=0; hset=0
        while IFS= read -r ln; do
          ln=${ln%$'\r'}
          if [[ $ln == $'\001'* ]]; then
            if (( cts > hm && files > hset )); then c=$(( c + 1 )); fi
            cts=${ln#$'\001'}; files=0; hset=0
          elif [ -n "$ln" ]; then
            files=$(( files + 1 ))
            [ "${ln##*/}" = "HANDOFF.md" ] && hset=$(( hset + 1 ))
          fi
        done <<<"$logout"
        if (( cts > hm && files > hset )); then c=$(( c + 1 )); fi
      fi
    fi
    # Sessions started for this project since the HANDOFF, from the hook log.
    # grep first, then jq on what survives. Measured over a 78KB / 393-line log:
    # pure bash over every line 220ms, jq --rawfile over every line 199ms, this 78ms
    # — because the cost is parsing 393 JSON objects, not reading the file, and only
    # ~30 of them are SessionStart. ISO-8601 UTC compares lexically, so no date math.
    local evlog="${HOME:-}/.claude/logs/events.jsonl" hiso out
    if [ -n "${HOME:-}" ] && [ -r "$evlog" ]; then
      TZ=UTC printf -v hiso '%(%Y-%m-%dT%H:%M:%SZ)T' "$hm"
      # `dir` is the Windows path as the payload gave it; the hook log records the
      # same form, and forward slashes are accepted too in case a machine differs.
      out=$(grep -F '"event":"SessionStart"' "$evlog" 2>/dev/null             | "$JQ_BIN" -rs --arg a "$dir" --arg b "$dirfs" --arg t "$hiso" '
                [ .[] | select(type=="object")
                      | select(.cwd==$a or .cwd==$b)
                      | select((.ts // "") > $t) ] | length' 2>/dev/null)
      out=${out%$'\r'}
      [[ $out =~ ^[0-9]+$ ]] && s=$out
    fi
  fi
  D_HAGE=$hage D_HTIME=$htime D_F=$f D_C=$c D_S=$s
  if [ "$f" = 0 ] && [ "$c" = 0 ] && [ "$s" = 0 ]; then D_STATE=ok; else D_STATE=stale; fi
}

render() {                       # render <json>
  local input="$1" now="${CC_NOW:-}"
  [ -n "$now" ] || printf -v now '%(%s)T' -1   # builtin: no `date` spawn

  # ---- ONE jq call for every field. ----
  # Separator is \x1f (unit separator), NOT tab: with IFS=$'\t' the tab is IFS
  # *whitespace*, so an empty field collapses and every field after it shifts left by
  # one. That is exactly what broke this script when Claude Code 2.1.275 dropped
  # `.permission_mode` (field 9 of 17): `hit` then held `warm` and `ttl` held `misses`,
  # printing the literal `❄true%/0`, and `dir` held a token count, so `git -C 110791`
  # failed and the bar claimed "sin HANDOFF" on a freshly committed repo.
  # Every access uses `?` so an unknown-shaped payload degrades to ⚠ instead of erroring.
  # A here-string costs ~0.7ms; `printf ... | jq` costs an extra fork (~65ms here).
  # rules/thresholds.json rides along in the SAME call (--slurpfile): reading it separately
  # would cost a second fork on every render. A thresholds file that exists but does not
  # parse makes the whole call fail, so we retry without it — that is how "broken
  # thresholds" stops looking exactly like "broken payload".
  local raw th_bad=0
  local -a jqargs=(-rj)
  if [ -n "$TH_FILE" ]; then jqargs+=(--slurpfile TH "$TH_FILE")
  else                       jqargs+=(--argjson TH '[]'); fi
  raw=$("$JQ_BIN" "${jqargs[@]}" "$JQ_PROG" 2>/dev/null <<<"$input")
  if [ -z "$raw" ] && [ -n "$TH_FILE" ]; then
    raw=$("$JQ_BIN" -rj --argjson TH '[]' "$JQ_PROG" 2>/dev/null <<<"$input")
    [ -n "$raw" ] && th_bad=1
  fi

  if [ -z "$raw" ]; then
    printf '%s\n' "${RED}⚠ JSON${R}"
    return 0
  fi

  local -a F
  IFS=$'\037' read -r -a F <<<"$raw"
  local i
  for i in "${!F[@]}"; do F[i]=${F[i]%$'\r'}; done   # jq.exe (native Windows) emits CRLF
  # A payload that yields fewer fields than we asked for is a schema change, not data.
  while (( ${#F[@]} < 21 )); do F+=("$S"); done

  local model=${F[0]}  effort=${F[1]}   size=${F[2]}  cost=${F[3]}  ms=${F[4]}
  local five=${F[5]}   week=${F[6]}     name=${F[7]}  addl=${F[8]}  dell=${F[9]}
  local dir=${F[10]}   used=${F[11]}    hit=${F[12]}  warm=${F[13]} ttl=${F[14]}
  local miss=${F[15]}  expires=${F[16]} causes=${F[17]}
  local sid=${F[18]}   thblob=${F[19]}  labels=${F[20]}

  # ---- thresholds ----
  # CC_CTX_* stay as per-machine overrides; the defaults are the file's, never this file's.
  if (( th_bad == 0 )) && th_load "$thblob"; then
    TH_OK=1
    GREEN_K=${CC_CTX_GREEN_K:-${TH_VALUE[context-amber]}}
    RED_K=${CC_CTX_RED_K:-${TH_VALUE[context-red]}}
  fi
  CAUSES_TXT=""
  if [ "$causes" != "$S" ] && [ "$causes" != "$E" ]; then CAUSES_TXT=$causes; fi

  # ---------------------------------------------------------------- line 1: context
  local line1
  if [ "$model" = "$S" ]; then line1="${B}${AMB}⚠ modelo${R}"; else line1="${B}${model}${R}"; fi
  if [ "$effort" != "$S" ] && [ "$effort" != "$E" ]; then line1+=" ·${effort}"; fi
  if [ -n "$NODE" ]; then line1+=" @${NODE}"; else line1+=" @${WARN}"; fi

  local ac_k=0 win="?" used_k=-1 pct=0 ctx
  if [ "$size" != "$S" ] && (( size > 0 )); then
    # Where auto-compact fires. Claude Code exports settings env to the commands it
    # runs; accepts 400000 | 400k | 1M. Falls back to ~97% of the window.
    local rawac=${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}
    case "$rawac" in
      *[kK])       ac_k=${rawac%[kK]} ;;
      *[mM])       ac_k=$(( ${rawac%[mM]} * 1000 )) ;;
      ''|*[!0-9]*) ac_k=$(( size * 97 / 100000 )) ;;
      *)           ac_k=$(( rawac / 1000 )) ;;
    esac
    (( ac_k > size/1000 )) && ac_k=$(( size / 1000 ))
    if (( size >= 1000000 )); then win="$(( size / 1000000 ))M"; else win="$(( size / 1000 ))k"; fi
  fi

  if [ "$used" = "$S" ] || [ "$size" = "$S" ] || (( size <= 0 )); then
    ctx="${AMB}⚠ contexto${R}"          # unknown is not zero
  else
    used_k=$(( used / 1000 ))
    pct=$(( used * 100 / size ))
    # No thresholds, no bands: an uncoloured bar is honest, a green one would be a claim.
    local col=""
    if (( TH_OK )); then
      if   (( used_k >= RED_K ));   then col=$RED
      elif (( used_k >= GREEN_K )); then col=$AMB
      else                               col=$GRN; fi
    fi
    # The bar spans 0..auto-compact, so it is a true progress meter toward the hard
    # limit. Colour comes from the QUALITY bands; ┋ marks RED_K ("compact by here").
    local span=$ac_k; (( span < 1 )) && span=1
    local filled=$(( used_k * W / span )); (( filled > W )) && filled=$W
    local mark=-1; (( TH_OK && RED_K < span )) && mark=$(( RED_K * W / span ))
    local bar="" j
    for ((j=0;j<W;j++)); do
      if   (( j == mark ));  then bar+="┋"
      elif (( j < filled )); then bar+="▓"
      else                        bar+="░"; fi
    done
    local over=""; (( TH_OK && used_k >= RED_K )) && over=" ⚠"
    ctx="${col}${bar} ${used_k}k${R}/${ac_k}k${over} · ${pct}% of ${win}"
  fi
  line1+=" ${ctx}"

  # `printf -v`, never `x=$(printf ...)`: a command substitution forks even for a
  # builtin, and a fork costs ~28ms on this box. Three of them were ~84ms of nothing.
  local rt_m=-1 tmp
  if [ "$cost" != "$S" ]; then printf -v tmp ' · $%.2f' "$cost"; line1+=$tmp
  else line1+=" · \$${WARN}"; fi
  if [ "$ms" != "$S" ]; then rt_m=$(( ms / 60000 )); line1+=" · ${rt_m}m"
  else line1+=" · ${WARN}m"; fi

  # ---- cache: ONE word and ONE number, in ONE place (here, next to cost and time). ----
  # The question it answers is "how long do I have before the next turn pays to rewrite
  # the context?", so the number is minutes left on `expires_at`, never the hit ratio (that
  # moved to line 2) and never the TTL label. `prompt_cache: null` (before the first call)
  # prints nothing; a cache object we cannot read prints ⚠.
  # cl_m is the metric `cache-cooling` is measured against: minutes left WHILE WARM. A cold
  # cache has no countdown, so it is -1 there too and cooling cannot fire on it — "cold" is
  # stated by cstate, not smuggled into the number.
  # The words come from thresholds.json `labels`; without that file only the symbols show.
  local hit_i=-1 cl_m=-1 cstate=none lw="" lc="" lx=""
  [ "$hit" = "$S" ] || [ "$hit" = "$E" ] || hit_i=$hit
  if (( TH_OK )); then IFS=$'\035' read -r lw lc lx <<<"$labels"; fi
  if [ "$warm" != "$E" ]; then
    if [ "$warm" = 0 ]; then
      cstate=cold
    elif [ "$expires" != "$S" ] && [ "$expires" != "$E" ]; then
      if (( expires - now <= 0 )); then cstate=cold
      else cl_m=$(( (expires - now) / 60 )); cstate=warm; fi
    elif [ "$warm" = 1 ]; then
      cstate=warm
    else
      cstate=unknown
    fi
    (( TH_OK )) && [ "$cstate" = warm ] && th_fires cache-cooling && cstate=cooling
    local cnum=""
    if (( cl_m == 0 )); then cnum="<1m"; elif (( cl_m > 0 )); then cnum="${cl_m}m"; fi
    local cseg=""
    case "$cstate" in
      warm|cooling)
        local ccol2=""; (( TH_OK )) && ccol2=$GRN
        local word=$lw; [ "$cstate" = cooling ] && { ccol2=$AMB; word=$lc; }
        cseg="⚡"; [ -n "$word" ] && cseg+=" ${word}"
        if [ -n "$cnum" ]; then
          if [ -n "$word" ]; then cseg+=" · ${cnum}"; else cseg+=" ${cnum}"; fi
        fi
        cseg="${ccol2}${cseg}${R}" ;;
      cold)
        cseg="❄"; [ -n "$lx" ] && cseg+=" ${lx}"
        (( TH_OK )) && cseg="${CYN}${cseg}${R}" ;;
      *)
        cseg="${AMB}⚠ caché${R}" ;;
    esac
    line1+=" · ${cseg}"
  fi

  # ---------------------------------------------------------------- line 2: the rest
  # NOTE: `.permission_mode` was dropped from the payload in 2.1.275 (0/35 renders in
  # the captured sample, across 2.1.274/275/276). There is no substitute field, so the
  # BYPASS / plan / dontAsk guard is gone from the bar rather than guessed at.
  local line2="" five_i=-1
  if   [ "$five" = "$E" ]; then :
  elif [ "$five" = "$S" ]; then line2+="5h ${WARN}"
  else five_i=${five%.*}; printf -v tmp '5h %.0f%%' "$five"; line2+=$tmp; fi
  if   [ "$week" = "$E" ]; then :
  elif [ "$week" = "$S" ]; then line2+="  7d ${WARN}"
  else printf -v tmp '  7d %.0f%%' "$week"; line2+=$tmp; fi

  # Hit ratio: line 2, and only when it tells you something. At or above `cache-hit-ok` it
  # is noise next to the state on line 1; below it, it is the reason that state matters.
  # No thresholds file = no way to call it "fine", so it is always shown, uncoloured.
  if [ "$hit" = "$S" ]; then
    line2+="  hit ${WARN}"
  elif [ "$hit" != "$E" ] && { (( ! TH_OK )) || ! th_fires cache-hit-ok; }; then
    local ccol=""
    if (( TH_OK )); then
      if th_fires cache-cold; then ccol=$RED; else ccol=$AMB; fi
    fi
    line2+="  ${ccol}hit ${hit_i}%${R}"
    if   [ "$miss" = "$S" ]; then line2+=" (${AMB}⚠${R} miss)"
    elif [ "$miss" != "$E" ] && (( miss > 0 )); then line2+=" (${miss} miss)"; fi
  elif [ "$miss" = "$S" ]; then
    line2+="  (${AMB}⚠${R} miss)"
  fi

  if [ "$addl" = "$S" ] || [ "$dell" = "$S" ]; then
    line2+="  ${AMB}⚠ diff${R}"
  elif (( addl > 0 || dell > 0 )); then
    line2+="  ${GRN}+${addl}${R}/${RED}-${dell}${R}"
  fi

  # ---- Git: one `git status --porcelain=v2 --branch`, parsed with bash builtins. ----
  # `dir` arrives as a Windows path (C:\...). git accepts it; bash file tests want
  # forward slashes, and the hook log records the backslash form, so keep both.
  local dirfs="" gitflag="" ahead=-1 branch="" upstream="" behind=0
  local modified=0 untracked=0 gs="" have_git=0
  local -a dirty=()
  if [ "$dir" != "$S" ]; then
    dirfs=${dir//\\//}
    if gs=$(git -C "$dirfs" status --porcelain=v2 --branch 2>/dev/null); then have_git=1; fi
  fi
  if (( have_git )) && [ -n "$gs" ]; then
    local ln ab
    while IFS= read -r ln; do
      case "$ln" in
        '# branch.head '*)     branch=${ln#\# branch.head } ;;
        '# branch.upstream '*) upstream=${ln#\# branch.upstream } ;;
        '# branch.ab '*)       ab=${ln#\# branch.ab }
                               ahead=${ab%% *}; ahead=${ahead#+}
                               behind=${ab##* }; behind=${behind#-} ;;
        '1 '*|'2 '*)           modified=$(( modified + 1 )); dirty+=("${ln##* }") ;;
        '? '*)                 untracked=$(( untracked + 1 )); dirty+=("${ln#\? }") ;;
      esac
    done <<<"$gs"
    if [ "$branch" = "(detached)" ] || [ -z "$branch" ]; then
      branch=$(git -C "$dirfs" rev-parse --short HEAD 2>/dev/null) || branch="?"
      [ -n "$branch" ] || branch="?"
    fi
    gitflag="⎇ ${branch}"
    if [ -z "$upstream" ]; then
      gitflag+=" ⊘"
    else
      local up_txt="↑${ahead}" oldest_ts
      if (( ahead > 0 )); then
        # Amber only once unpushed work has sat for >2h — a fresh commit is not at risk.
        oldest_ts=$(git -C "$dirfs" log '@{u}..HEAD' --format=%at 2>/dev/null | tail -1)
        if [ -n "$oldest_ts" ] && (( now - oldest_ts >= 7200 )); then
          up_txt="${AMB}↑${ahead}${R}"
        fi
      fi
      gitflag+=" ${up_txt} ↓${behind}"
    fi
    gitflag+=" ●${modified} ?${untracked}"
  fi

  # ---- HANDOFF drift (computed by drift_scan; see above). ----
  drift_scan "$dir" "$dirfs" "$have_git" "$now" "${dirty[@]}"
  # The drift counters become metrics here. "?" (could not be computed) is -1, never 0.
  MD_F=-1; [ "$D_F" = "?" ] || MD_F=$D_F
  MD_S=-1; [ "$D_S" = "?" ] || MD_S=$D_S
  local flag fresh=0
  case "$D_STATE" in
    none) flag="${AMB}⚠ sin HANDOFF${R}" ;;
    ok)   flag="${GRN}✓HANDOFF${R}"; fresh=1 ;;
    *)    local hcol=$AMB
          # Same red band the SessionStart hook uses, and now the same two numbers.
          if (( TH_OK )) && { th_fires handoff-drift-files || th_fires handoff-drift-sessions; }; then
            hcol=$RED
          fi
          flag="${hcol}⚠HANDOFF ${D_HTIME} ·${D_F}f ·${D_C}c ·${D_S}s${R}" ;;
  esac

  # ONE contextual hint, highest priority only. A status line is for state, not
  # analysis: if it ever shows two hints at once, it has stopped being glanceable.
  # Which one, in what order and with what words: rules/thresholds.json, not this file.
  local hint=""
  if (( TH_OK )); then th_pick && hint=$HINT; fi

  [ -n "$gitflag" ] && line2+="  ${gitflag}"
  line2+="  ${flag}"
  # Say it out loud instead of quietly dropping the bands: a bar with no thresholds is
  # still a bar, but it has stopped watching anything.
  (( TH_OK )) || line2+="  ${AMB}⚠ umbrales${R}"
  [ "$name" = "$S" ] || line2+="  [${name}]"
  [ -n "$hint" ] && line2+="  ${MAG}${hint}${R}"

  # ---- snapshot for /ahora ----
  # The 5h quota and the cache ratio exist ONLY in this payload: they are not in the
  # transcripts (visor.py says so in its own docstring). So the bar writes down what it
  # just saw, keyed by session so two windows cannot overwrite each other, and /ahora
  # reads it back WITH ITS AGE. Best effort: `printf >` is a builtin, and a snapshot that
  # fails to write must never cost you a render.
  local sdir=${CC_STATE_DIR:-}
  [ -n "$sdir" ] || { [ -n "${HOME:-}" ] && sdir="$HOME/.claude/state"; }
  if [ -n "$sdir" ] && [ "$sid" != "$S" ] && [ "$sid" != "$E" ]; then
    local sid_safe=${sid//[^A-Za-z0-9._-]/_}
    local dirj="" week_i=-1 cost_s=-1
    [ "$dir" = "$S" ] || dirj=$dir
    [ "$week" = "$S" ] || [ "$week" = "$E" ] || week_i=${week%.*}
    [ "$cost" = "$S" ] || cost_s=$cost
    [ -d "$sdir" ] || mkdir -p "$sdir" 2>/dev/null
    # jq builds it, printf does not. Every string here comes from the outside world —
    # a branch name, a path, the causes text — and git allows a `"` in a refname, so a
    # printf template was one `git switch -c 'feat/"x"'` away from writing a file that
    # /ahora could never parse again. Everything goes in as --arg (jq quotes it) and the
    # numbers are converted inside jq, so a missing value lands as -1 instead of
    # poisoning the whole document. Written to .tmp and moved: a half-written snapshot
    # is not a zero.
    local snapf="$sdir/$sid_safe.json"
    "$JQ_BIN" -nc \
      --arg ts "$now" --arg session "$sid_safe" --arg five "$five_i" --arg week "$week_i" \
      --arg ck "$used_k" --arg cp "$pct" --arg lk "$ac_k" --arg cache "$hit_i" \
      --arg cleft "$cl_m" --arg cstate "$cstate" \
      --arg smin "$rt_m" --arg ahead "$ahead" --arg behind "$behind" \
      --arg modified "$modified" --arg untracked "$untracked" \
      --arg handoff "$D_STATE" --arg handoff_age "$D_HAGE" \
      --arg hdirty "$MD_F" --arg hsess "$MD_S" --arg fresh "$fresh" \
      --arg causes "$CAUSES_TXT" --arg branch "$branch" --arg dir "$dirj" \
      --arg cost "$cost_s" --arg hint_id "$HINT_ID" \
      '{ts:($ts|tonumber? // 0), session:$session,
        five_pct:($five|tonumber? // -1), week_pct:($week|tonumber? // -1),
        context_k:($ck|tonumber? // -1), context_pct:($cp|tonumber? // -1),
        limit_k:($lk|tonumber? // -1), cache_pct:($cache|tonumber? // -1),
        cache_left_min:($cleft|tonumber? // -1), cache_state:$cstate,
        session_min:($smin|tonumber? // -1), ahead:($ahead|tonumber? // -1),
        behind:($behind|tonumber? // -1), modified:($modified|tonumber? // -1),
        untracked:($untracked|tonumber? // -1), handoff:$handoff,
        handoff_age:$handoff_age, handoff_dirty:($hdirty|tonumber? // -1),
        handoff_sessions:($hsess|tonumber? // -1), fresh:($fresh|tonumber? // 0),
        causes:$causes, branch:$branch, dir:$dir,
        cost_usd:($cost|tonumber? // -1), hint_id:$hint_id}' \
      > "$snapf.tmp" 2>/dev/null \
      && mv -f "$snapf.tmp" "$snapf" 2>/dev/null || rm -f "$snapf.tmp" 2>/dev/null
  fi

  # ---- enjambre: nodes alive, jobs running, today's usage summed over every machine.
  # enjambre/tools/visor/build.py writes `<epoch>\t<text>` here every 5 min and pushes the
  # same file to each node. Builtins only (no fork, no ssh): the bar renders every turn.
  # No file = no segment, so a machine without the swarm shows nothing. Older than 15 min
  # = the builder stopped: say so with its age instead of showing old numbers as current.
  local enj_f=${CC_ENJ_SUMMARY:-$HOME/.enjambre/visor/summary.txt} enj_ts="" enj_txt=""
  if [ -r "$enj_f" ] && IFS=$'\t' read -r enj_ts enj_txt < "$enj_f" && [[ $enj_ts =~ ^[0-9]+$ ]]; then
    if (( now - enj_ts > 900 )); then line2+="  ${AMB}enj ⌛$(( (now - enj_ts) / 60 ))m${R}"
    else line2+="  enj ${enj_txt}"; fi
  fi

  line2=${line2#"${line2%%[! ]*}"}   # drop leading padding when the first group is absent
  printf '%s\n%s\n' "$line1" "$line2"
}

# ------------------------------------------------------------------ selftest / main
if [ "${1:-}" = "--selftest" ]; then
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  runner="$here/../../tests/statusline_test.sh"
  if [ ! -f "$runner" ]; then
    printf '%s\n' "no hay tests/ junto a este script (busqué $runner)."
    printf '%s\n' "--selftest corre desde la copia del repo (claude-kit/home/.claude/statusline.sh),"
    printf '%s\n' "no desde ~/.claude/. Ver README.md, sección «Status line»."
    exit 2
  fi
  exec bash "$runner"
fi

# `--drift <dir>`: print the HANDOFF drift as plain fields, for the hooks.
#   state hage f c s    e.g.  stale 26h 1 0 1   ·   ok 3h 0 0 0   ·   none ? ? ? ?
# There is exactly ONE definition of drift (drift_scan above) and both the bar and the
# SessionStart hook read it from here, so they can never disagree.
if [ "${1:-}" = "--drift" ]; then
  d=${2:-.}
  dfs=${d//\\//}
  hg=0; g=""
  if g=$(git -C "$dfs" status --porcelain=v2 2>/dev/null); then hg=1; fi
  dty=()
  if (( hg )); then
    while IFS= read -r l; do
      case "$l" in
        '1 '*|'2 '*) dty+=("${l##* }") ;;
        '? '*)       dty+=("${l#\? }") ;;
      esac
    done <<<"$g"
  fi
  printf -v n '%(%s)T' -1
  drift_scan "$d" "$dfs" "$hg" "${CC_NOW:-$n}" "${dty[@]}"
  printf '%s %s %s %s %s\n' "$D_STATE" "$D_HAGE" "$D_F" "$D_C" "$D_S"
  exit 0
fi

# `--ahora [session-id]`: the three lines the /ahora skill prints, and nothing else.
# It measures NOTHING itself. It reads the snapshot the bar wrote for that session and
# re-evaluates the SAME rules/thresholds.json against it, so the skill and the bar can
# never give different advice. Missing, unreadable or old: it says so instead of guessing.
if [ "${1:-}" = "--ahora" ]; then
  sid=${2:-${CLAUDE_SESSION_ID:-}}
  sid=${sid//[^A-Za-z0-9._-]/_}
  sdir=${CC_STATE_DIR:-}
  [ -n "$sdir" ] || sdir="${HOME:-.}/.claude/state"

  # A skill invocation does NOT carry $CLAUDE_SESSION_ID (measured: the variable is not
  # exported to the shell a skill runs). So with no id, fall back to the newest snapshot
  # written for THIS directory — that is the window you are typing in. Two windows open on
  # the same repo can still collide, which is exactly why line 1 names the session it used.
  norm() {                    # norm <path> -> comparable form (msys, lowercase, no CR)
    local p=${1%$'\r'}     # jq.exe ends its line in CRLF and `read` only eats the LF
    p=${p//\\//}
    case "$p" in [A-Za-z]:/*) p="/${p:0:1}${p:2}" ;; esac
    printf '%s' "${p,,}"
  }
  guessed=0
  if [ -z "$sid" ]; then
    here=$(norm "$PWD")
    pickts=-1
    while IFS=$'\037' read -r sts sses sdirname; do
      [ -n "$sses" ] || continue
      [ "$(norm "$sdirname")" = "$here" ] || continue
      [[ $sts =~ ^[0-9]+$ ]] || continue
      (( sts > pickts )) && { pickts=$sts; sid=$sses; }
    done < <("$JQ_BIN" -r '[(.ts//0),(.session//""),(.dir//"")] | join("\u001f")' "$sdir"/*.json 2>/dev/null)
    sid=${sid//[^A-Za-z0-9._-]/_}
    [ -n "$sid" ] && guessed=1
  fi
  snap="$sdir/$sid.json"
  printf -v nowa '%(%s)T' -1
  nowa=${CC_NOW:-$nowa}

  say3() { printf '%s\n%s\n%s\n' "$1" "$2" "$3"; exit 0; }

  [ -n "$sid" ] && [ -r "$snap" ] && say3x=0 || say3     "ahora: no hay snapshot de esta sesión (${snap})"     "hacé: dejá que la barra de estado renderice una vez — el snapshot lo escribe ella"     "por qué: la cuota 5h y la caché solo existen en el payload de la barra, no en los transcripts (visor.py)"

  raw=$("$JQ_BIN" -rj '[(.ts//-1),(.five_pct//-1),(.week_pct//-1),(.context_k//-1),
        (.context_pct//-1),(.limit_k//-1),(.cache_pct//-1),(.session_min//-1),(.ahead//-1),
        (.handoff//"?"),(.handoff_age//"?"),(.handoff_dirty//-1),(.handoff_sessions//-1),
        (.fresh//0),(.causes//""),(.branch//""),(.cache_left_min//-1),
        (.cache_state//"none")] | map(tostring) | join("\u001f")'         "$snap" 2>/dev/null)
  [ -n "$raw" ] || say3     "ahora: el snapshot existe pero no se deja leer (${snap})"     "hacé: borralo; la barra lo reescribe en el próximo render"     "por qué: un snapshot a medio escribir no es un cero, y estas tres líneas no inventan números"

  IFS=$'\037' read -r -a A <<<"$raw"
  five_i=${A[1]} used_k=${A[3]} hit_i=${A[6]} rt_m=${A[7]} ahead=${A[8]}
  MD_F=${A[11]} MD_S=${A[12]} fresh=${A[13]} CAUSES_TXT=${A[14]} cl_m=${A[16]:--1}

  thblob=""
  [ -n "$TH_FILE" ] && thblob=$("$JQ_BIN" -rj -n --slurpfile TH "$TH_FILE" "$JQ_TH" 2>/dev/null)
  th_load "$thblob" || say3     "ahora: no puedo leer los umbrales (${TH_FILE:-falta rules/thresholds.json junto a statusline.sh})"     "hacé: bash kit-update.sh, que repone el archivo desde el repo"     "por qué: los umbrales no están en el código; sin ese archivo no hay contra qué comparar"

  age=$(( nowa - A[0] )); (( age < 0 )) && age=0
  if   (( age < 90 ));   then agetxt="${age}s"
  elif (( age < 5400 )); then agetxt="$(( age / 60 ))m"
  else                        agetxt="$(( age / 3600 ))h"; fi
  (( age > 900 )) && agetxt="$agetxt, puede estar viejo"

  l1="ahora:"
  if (( used_k >= 0 )); then
    l1="$l1 contexto ${used_k}k"
    (( A[5] > 0 ))   && l1="$l1/${A[5]}k"
    (( A[4] >= 0 ))  && l1="$l1 (${A[4]}%)"
  else
    l1="$l1 contexto ?"
  fi
  (( five_i >= 0 )) && l1="$l1 · 5h ${five_i}%"
  (( A[2] >= 0 ))   && l1="$l1 · 7d ${A[2]}%"
  case "${A[17]:-none}" in
    warm|cooling) l1="$l1 · caché ${A[17]}"; (( cl_m >= 0 )) && l1="$l1 ${cl_m}m" ;;
    cold)         l1="$l1 · caché fría" ;;
  esac
  (( hit_i >= 0 ))  && l1="$l1 · hit ${hit_i}%"
  (( rt_m >= 0 ))   && l1="$l1 · sesión $(( rt_m / 60 ))h$(( rt_m % 60 ))m"
  (( ahead >= 0 ))  && l1="$l1 · ↑${ahead}"
  l1="$l1 · HANDOFF ${A[9]} ${A[10]} · snapshot de hace ${agetxt}"
  (( guessed )) && l1="$l1 (sesión ${sid:0:8}, elegida por directorio)"

  if th_pick; then
    say3 "$l1" "hacé: ${HINT}"       "por qué: ${HINT_ID} (${TH_METRIC[$HINT_ID]} ${TH_OP[$HINT_ID]} ${TH_VALUE[$HINT_ID]}) · rules/thresholds.json"
  fi
  say3 "$l1" "hacé: nada, seguí" "por qué: ningún umbral de rules/thresholds.json está cruzado con estos números"
fi

# Slurp stdin with the `read` builtin, not `$(cat)`: one fork+exec fewer (~80ms here).
# `read -d ''` returns non-zero at EOF with no NUL, which is the expected path.
IFS= read -r -d '' payload || true
render "$payload"
