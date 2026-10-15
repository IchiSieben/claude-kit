#!/usr/bin/env bash
# tests/prepush_test.sh — the pre-push guard, proved against throwaway repos.
#   1. verify.sh fails on purpose  -> the push is refused and the remote does not move;
#   2. verify.sh passes            -> the same push goes through;
#   3. no verify.sh                -> the hook lets the push through and says why;
#   4. the installer never overwrites a pre-push that differs from the template.
set -uo pipefail
cd "$(dirname "$0")/.."
pass=0 fail=0
ok()  { printf '  OK    %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FALLA %s — %s\n' "$1" "$2"; fail=$((fail + 1)); }
# The suite may itself run inside a pre-push hook (verify.sh): never inherit that repo.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main -c core.autocrlf=false "$@"; }
echo "pre-push: verify.sh en rojo niega el push (repos temporales)"

g init -q --bare "$T/remote.git"
g init -q "$T/w"
g -C "$T/w" remote add origin "$T/remote.git"
printf 'one\n' > "$T/w/a.txt"
g -C "$T/w" add a.txt && g -C "$T/w" commit -qm one
bash tools/install-hooks.sh "$T/w" > "$T/install.log" 2>&1 \
  && [ "$(git -C "$T/w" config core.hooksPath)" = .githooks ] && [ -x "$T/w/.githooks/pre-push" ] \
  && ok "instalador: copia el hook y fija core.hooksPath" \
  || bad "instalador: copia el hook y fija core.hooksPath" "$(tail -1 "$T/install.log")"

# 1. a verify.sh that fails on purpose (the "red test" in a temporary worktree).
printf '#!/usr/bin/env bash\necho "1 comprobacion FALLA (a proposito)"; exit 1\n' > "$T/w/verify.sh"
g -C "$T/w" add verify.sh .githooks && g -C "$T/w" commit -qm red
if g -C "$T/w" push -q origin main > "$T/p1.log" 2>&1; then
  bad "verify en rojo: push rechazado" "el push salió 0"
elif grep -q 'push refused' "$T/p1.log" && ! git -C "$T/remote.git" rev-parse -q --verify refs/heads/main > /dev/null; then
  ok "verify en rojo: push rechazado y el remoto no se movió"
else
  bad "verify en rojo: push rechazado" "$(tail -2 "$T/p1.log" | tr '\n' ' ')"
fi

# 2. same repo, verify.sh green: the push goes through.
printf '#!/usr/bin/env bash\necho "TODO OK"; exit 0\n' > "$T/w/verify.sh"
g -C "$T/w" commit -qam green
if g -C "$T/w" push -q origin main > "$T/p2.log" 2>&1 \
   && [ "$(git -C "$T/remote.git" rev-parse main)" = "$(git -C "$T/w" rev-parse HEAD)" ]; then
  ok "verify en verde: el push pasa"
else
  bad "verify en verde: el push pasa" "$(tail -2 "$T/p2.log" | tr '\n' ' ')"
fi

# 3. no verify.sh at all: nothing to check, the push goes through and the hook says so.
g -C "$T/w" rm -q verify.sh && g -C "$T/w" commit -qm noverify
if g -C "$T/w" push origin main > "$T/p3.log" 2>&1 && grep -q 'nothing to check' "$T/p3.log"; then
  ok "sin verify.sh: el push pasa y el hook lo dice"
else
  bad "sin verify.sh: el push pasa y el hook lo dice" "$(tail -2 "$T/p3.log" | tr '\n' ' ')"
fi

# 4. a hand-edited hook is never overwritten.
g init -q "$T/x"
mkdir -p "$T/x/.githooks" && printf '#!/bin/sh\nexit 0\n' > "$T/x/.githooks/pre-push"
if bash tools/install-hooks.sh "$T/x" > "$T/i4.log" 2>&1; then
  bad "instalador: no pisa un pre-push distinto" "salió 0"
elif grep -q 'differs from the template' "$T/i4.log" && grep -q 'exit 0' "$T/x/.githooks/pre-push"; then
  ok "instalador: no pisa un pre-push distinto"
else
  bad "instalador: no pisa un pre-push distinto" "$(tail -1 "$T/i4.log")"
fi

echo
if (( fail )); then printf '%d OK, %d FALLA(S).\n' "$pass" "$fail"; exit 1; fi
printf '%d OK, 0 fallas.\n' "$pass"
