#!/usr/bin/env bash
# Shared by sync-from-home.sh, sync-to-home.sh and verify.sh: the ONE list of what
# the mirror covers. Anything mirror_list does not print is out of bounds for the
# scripts, so a widened .gitignore alone can never make them copy more.
#
# Skills whose directory holds more than SKILL.md are not portable by SKILL.md alone
# (hyperframes-* and media-use come from their own installer) and are skipped.
SKIP_SKILLS='^(hyperframes|hyperframes-.*|media-use)$'

# The only settings.json keys that travel between machines. Everything else
# (plugins, marketplaces, theme, notifications, advisorModel, model, modelSettings...)
# is machine-local: modelSettings used to be listed here by mistake, which meant a
# per-machine effort override got clobbered on every sync-to-home. `model` left for
# the same reason on 2026-09-18: the repo pinned one model, so every sync silently
# reset the model the owner had chosen for the session he was in.
PORTABLE='["effortLevel","env","statusLine","hooks","promptCacheTtl"]'

# same_portable HOME REPO -> 0 if merging REPO's portable keys into HOME would change
# nothing, i.e. exactly when sync-to-home.sh would be a no-op. Machine-local
# additions inside a portable key (an extra env var) do not count as drift.
same_portable() {
  jq -se --argjson k "$PORTABLE" \
    '.[0] == (.[0] * (.[1] | with_entries(select(.key as $x | $k | index($x)))))' \
    "$1" "$2" >/dev/null
}

# mirror_list ROOT -> paths relative to ROOT (a .claude directory), one per line,
# only those that exist.
mirror_list() {
  local root="$1" f d name
  for f in CLAUDE.md MANUAL.md settings.json statusline.sh; do
    [ -f "$root/$f" ] && echo "$f"
  done
  # rules/*.json travels too: rules/thresholds.json is data the statusline and the hooks
  # READ at runtime, so a mirror that only carries *.md would install a bar with no bands.
  for f in "$root"/rules/*.md "$root"/rules/*.json "$root"/hooks/*.sh "$root"/agents/*.md; do
    [ -f "$f" ] && echo "${f#"$root"/}"
  done
  for d in "$root"/skills/*/; do
    [ -f "$d/SKILL.md" ] || continue
    d="${d%/}"; name="${d##*/}"
    [[ "$name" =~ $SKIP_SKILLS ]] && continue
    echo "skills/$name/SKILL.md"
  done
}

# copy_lf SRC DST -> copy with CRLF normalised to LF, creating parent dirs.
copy_lf() { mkdir -p "$(dirname "$2")"; tr -d '\r' < "$1" > "$2"; }

# same_lf A B -> 0 if identical modulo line endings.
same_lf() { cmp -s <(tr -d '\r' < "$1") <(tr -d '\r' < "$2"); }
