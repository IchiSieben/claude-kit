#!/usr/bin/env bash
# Appends one JSON line per lifecycle event to ~/.claude/logs/events.jsonl
# Seed data for the control-center dashboard (session, event, cwd, timestamp, agent).
#
# On SessionEnd it also sweeps ~/.claude/state/: the status line writes one ~500-byte
# snapshot per session there and nothing ever removed them. 24h is the cutoff because a
# snapshot is only useful to /ahora while the session it describes is alive, and a session
# still being typed in has its snapshot rewritten on every single render — so a file that
# has not been touched in a day belongs to a window that is gone.

# Read stdin ONCE: the payload is needed twice (the log line, and the event name that
# decides whether to sweep), and a hook only gets one shot at its stdin.
IFS= read -r -d '' payload || true

mkdir -p "$HOME/.claude/logs"
printf '%s' "$payload" | jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{ts:$ts, event:.hook_event_name, session:.session_id, cwd:.cwd, agent:(.agent_type // null), source:(.source // .trigger // .matcher // null), model:(.model // null)}' \
  >> "$HOME/.claude/logs/events.jsonl" 2>/dev/null

# This script is wired to several events; the sweep is for SessionEnd only.
event=$(printf '%s' "$payload" | jq -r '.hook_event_name // ""' 2>/dev/null)
if [ "$event" = "SessionEnd" ]; then
  state=${CC_STATE_DIR:-$HOME/.claude/state}
  # Best effort, always: a hook that fails must never be the reason a session cannot close.
  [ -d "$state" ] && find "$state" -maxdepth 1 -type f -name '*.json' -mmin +1440 -delete 2>/dev/null
fi
exit 0
