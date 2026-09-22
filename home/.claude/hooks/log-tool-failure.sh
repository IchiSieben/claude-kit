#!/usr/bin/env bash
# PostToolUseFailure(matcher: Bash) -> one JSON line per FAILED command.
#
# Why this hook exists: the PreCompact draft wants "commands that failed this session",
# and there was no source for it. events.jsonl only records lifecycle events, and the
# transcript's schema is undocumented and shifts between versions — parsing it is exactly
# the guessing game that broke the status line.
#
# The payload shape below was CAPTURED from a real 2.1.276 run, not guessed:
#   session_id, transcript_path, cwd, scratchpad_dir, prompt_id, permission_mode,
#   effort.level, hook_event_name, tool_name, tool_input.{command,description},
#   tool_use_id, error, is_interrupt, duration_ms
# Notes that matter:
#   - PostToolUse fires on SUCCESS only; failures come through PostToolUseFailure.
#   - `tool_response` is null on failure, so there is no structured exit code. The
#     `error` string starts with "Exit code N", so its first line is what we keep.
#   - `is_interrupt` is true when YOU stopped the command. That is not a failed command
#     and must not be logged as a lesson.
# Always exits 0. A hook that fails must never be the reason something else breaks.
set -u
LOG="$HOME/.claude/logs/tool-failures.jsonl"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || exit 0

command -v jq >/dev/null 2>&1 || exit 0

jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  # A command you interrupted is not a command that failed.
  select((.is_interrupt // false) == false)
  # Redact before writing. The log lives under ~/.claude/logs (git-ignored) and the draft
  # built from it is git-ignored too, but a token written to disk in clear is still a
  # token written to disk in clear. Truncation alone does not cover a secret at char 10.
  | ((.tool_input.command // "")
     # The dot is in the class on purpose: without it `sk-proj-AAA.BBB.CCC` redacted only
     # up to the first dot and leaked the rest. Over-redacting a filename is harmless;
     # under-redacting a key is not.
     | gsub("(?<k>(sk-|ghp_|gho_|ghs_|github_pat_|xox[baprs]-|AKIA|ASIA))[A-Za-z0-9_.\\-]+"; "\(.k)***")
     # `Bearer <token>` first, and as its own rule: the header-name rule below would
     # otherwise consume the word "Bearer" as if IT were the value and leave the actual
     # token in the clear. An auth scheme word is not a secret; what follows it is.
     | gsub("(?<k>(?i)(bearer|basic|token)\\s+)[A-Za-z0-9_.+/=\\-]{8,}"; "\(.k)***")
     | gsub("(?<k>(?i)(token|password|passwd|secret|api[-_]?key|authorization)\\s*[=:]\\s*(bearer\\s+|basic\\s+)?)\\S+"; "\(.k)***")
     | gsub("(?<k>(?i)--(pass|password|token|secret)[= ])\\S+"; "\(.k)***")
     | if length > 160 then .[0:160] + "…" else . end) as $cmd
  | {
      ts: $ts,
      session: .session_id,
      cwd: .cwd,
      tool: .tool_name,
      # First line of `error` only: it carries "Exit code N" without dragging stderr
      # (which can contain paths, hostnames or secrets) into the file.
      err: ((.error // "") | split("\n")[0] // ""),
      cmd: $cmd,
      desc: (.tool_input.description // null),
      ms: (.duration_ms // null),
      agent: (.agent_type // null)
    }' >> "$LOG" 2>/dev/null

exit 0
