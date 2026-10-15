#!/usr/bin/env bash
# claude-kit module `enjambre` · PreToolUse (Bash|PowerShell): block a raw `ssh <node>` to one
# of YOUR worker nodes outside the enjambre repos. A worker node takes work through enjambre
# (https://github.com/IchiSieben/enjambre: it routes, queues and keeps a ledger), so a raw
# `ssh <node>` from a project repo is a delegation nobody can see. rules/kit-enjambre.md is the
# policy; this hook is the mechanism. Installed only by `sync-to-home.sh --with enjambre`.
#
# Which hosts count as nodes: every `host = "..."` in enjambre's nodes.toml except `local`
# ($ENJAMBRE_NODES, default $ENJAMBRE_HOME/nodes.toml, default ENJAMBRE_HOME=$HOME/enjambre),
# plus the space-separated names in $ENJAMBRE_GUARD_HOSTS. No nodes known = nothing blocked.
#
# Blocks with exit 2 (stderr goes back to the model). Bypass once: `ENJAMBRE_RAW_SSH=1` in
# the command itself or in the environment; the bypass is logged to events.jsonl (raw_ssh=1).
# Fails open: no jq, bad payload or unreadable nodes.toml never stops a command.
# Bash-3.2 clean (macOS /bin/bash): no associative arrays, no ${var,,}.

IFS= read -r -d '' payload || true
# Fast path: this runs before every shell call; most never mention ssh.
case "$payload" in *ssh*) ;; *) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

us=$'\x1f'
fields=$(printf '%s' "$payload" | jq -j --arg us "$us" \
  '(.cwd // ""), $us, (.session_id // ""), $us, (.tool_input.command // "")' 2>/dev/null) || exit 0
cwd=${fields%%"$us"*}; rest=${fields#*"$us"}
sid=${rest%%"$us"*};   cmd=${rest#*"$us"}
[ -n "$cmd" ] || exit 0

# Exempt: any path component named enjambre or enjambre-* (Windows cwd has `\`): the swarm's
# own repos are where raw ssh to a node is the job.
p=${cwd//\\//}
case "/$p/" in */enjambre/*|*/enjambre-*) exit 0 ;; esac

# Node aliases: $ENJAMBRE_GUARD_HOSTS plus every `host = "..."` in nodes.toml except local.
aliases=" ${ENJAMBRE_GUARD_HOSTS:-} "
nodes=${ENJAMBRE_NODES:-${ENJAMBRE_HOME:-$HOME/enjambre}/nodes.toml}
if [ -r "$nodes" ]; then
  while IFS= read -r line; do
    case "$line" in
      host*=*\"*\"*)
        h=${line#*\"}; h=${h%%\"*}
        [ -n "$h" ] && [ "$h" != local ] && aliases="$aliases$h "
        ;;
    esac
  done < "$nodes"
fi

# Tokenise: shell separators become their own words, then walk the words. After an `ssh`
# word, skip options (and the argument of those that take one); the first other word is the
# destination. Quotes and $( ` around a word are stripped.
c=$cmd
for sep in ';' '&' '|' '(' ')' '`'; do c=${c//"$sep"/ ; }; done
c=${c//$'\n'/ ; }
# Only a word in COMMAND POSITION can be the ssh that runs (0e: `grep 'ssh mac' docs/` only
# searched text and was blocked). Command position = first word of a segment, after
# VAR=value assignments and after prefixes that run their argument (env, nohup, timeout 20,
# sudo, xargs, if/then/do, ...). `bash -c "ssh mac ls"` / `pwsh -Command` DO run it: the word
# after -c is in command position again. Known false positive left on purpose: a `;` or `|`
# inside a quoted grep pattern still splits it (fails closed; ENJAMBRE_RAW_SSH=1 passes it).
hit=""; state=0   # 0 command position, 1 after ssh, 2 ssh option argument, 3 other args, 4 shell args
set -f
for w in $c; do
  w=${w#\"}; w=${w#\'}; w=${w%\"}; w=${w%\'}; w=${w#\$}
  if [ "$w" = ";" ]; then state=0; continue; fi
  case $state in
    0) case "$w" in
         ssh|ssh.exe|*/ssh|*/ssh.exe|*\\ssh|*\\ssh.exe) state=1 ;;
         [A-Za-z_]*=*|env:*=*) ;;                          # assignment: still command position
         env|exec|command|builtin|nohup|time|sudo|nice|xargs|timeout|caffeinate|stdbuf|\
         if|then|else|elif|do|while|until|!|\{|\&) state=5 ;;
         bash|sh|zsh|dash|*/bash|*/sh|*/zsh|bash.exe|powershell|powershell.exe|pwsh|pwsh.exe) state=4 ;;
         *) state=3 ;;
       esac ;;
    5) case "$w" in                                         # prefix: skip its options/numbers
         -*|[0-9]*|[A-Za-z_]*=*) ;;
         ssh|ssh.exe|*/ssh|*/ssh.exe|*\\ssh|*\\ssh.exe) state=1 ;;
         bash|sh|zsh|*/bash|*/sh|*/zsh|powershell|powershell.exe|pwsh|pwsh.exe) state=4 ;;
         env|exec|command|nohup|time|sudo|nice|xargs|timeout|caffeinate|stdbuf) ;;
         *) state=3 ;;
       esac ;;
    3) ;;
    4) case "$w" in -c|-lc|-ic|-Command|-command|-c*) state=0 ;; esac ;;
    2) state=1 ;;
    1) case "$w" in
         -[BbcDEeFIiJLlmOoPpQRSWw]) state=2 ;;
         -*) ;;
         *) d=${w#*@}; d=${d%%:*}
            case "$aliases" in *" $d "*) hit=$d; break ;; esac
            state=0 ;;
       esac ;;
  esac
done
set +f
[ -n "$hit" ] || exit 0

case "$cmd" in *ENJAMBRE_RAW_SSH=1*) bypass=1 ;; *) bypass=${ENJAMBRE_RAW_SSH:-0} ;; esac
if [ "$bypass" = 1 ]; then
  mkdir -p "$HOME/.claude/logs"
  jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg s "$sid" --arg d "$cwd" --arg h "$hit" \
    '{ts:$ts, event:"PreToolUse", session:$s, cwd:$d, agent:null, source:"enjambre-ssh-guard",
      model:null, raw_ssh:1, host:$h}' >> "$HOME/.claude/logs/events.jsonl" 2>/dev/null
  exit 0
fi

cat >&2 <<EOF
enjambre-ssh-guard: \`ssh $hit\` is a worker node; raw ssh to it is blocked outside the enjambre repos.
Delegate through enjambre instead: python ${ENJAMBRE_HOME:-$HOME/enjambre}/enjambre.py run|status|collect
(see the repo's docs/DELEGAR.md if it has one). To bypass once, logged: ENJAMBRE_RAW_SSH=1
EOF
exit 2
