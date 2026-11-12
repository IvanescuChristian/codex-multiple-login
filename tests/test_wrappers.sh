#!/usr/bin/env bash
# Offline tests for bin/codex: uses a fake "real" binary that only prints what
# the wrapper sets. No network, no real CLI, no login.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
check() { # name expected actual
  if [[ "$2" == "$3" ]]; then echo "ok   - $1"; else echo "FAIL - $1: expected [$2] got [$3]"; fail=1; fi
}

mkdir -p "$T/real" "$T/wrap"
printf '#!/usr/bin/env bash\necho "HOME=$HOME CODEX_HOME=${CODEX_HOME:-unset} ARGS=$*"\n' > "$T/real/codex"
chmod +x "$T/real/codex"
cp "$ROOT/bin/codex" "$T/wrap/codex"
printf '%s\n' "$T/real/codex" > "$T/wrap/.codex-real-bin"
export HOME="$T/home"; mkdir -p "$HOME"
unset CODEX_HOME AGY_LOGIN_NEW_PROFILES_DIR CODEX_LOGIN_NEW_PROFILES_DIR

out="$("$T/wrap/codex" --login_new work exec --foo bar 2>/dev/null)"
check "codex sets CODEX_HOME, HOME untouched" "HOME=$HOME CODEX_HOME=$HOME/.codex-profiles/work ARGS=exec --foo bar" "$out"
out="$("$T/wrap/codex" exec x 2>/dev/null)"
check "without flag is untouched" "HOME=$HOME CODEX_HOME=unset ARGS=exec x" "$out"
out="$(CODEX_LOGIN_NEW_PROFILES_DIR="$T/p" "$T/wrap/codex" --login_new=w a 2>/dev/null)"
check "env override + --login_new=" "HOME=$HOME CODEX_HOME=$T/p/w ARGS=a" "$out"

mkdir -p "$HOME/.codex-profiles/a" "$HOME/.codex-profiles/b"; touch "$HOME/.codex-profiles/a/auth.json"
out="$("$T/wrap/codex" --login_new --list)"
check "list shows login state" "yes" "$(grep -q 'a  *logged in' <<<"$out" && grep -q 'b  *not logged in' <<<"$out" && echo yes)"
echo "[user]" > "$HOME/.gitconfig"
"$T/wrap/codex" --login_new cx exec >/dev/null 2>&1
check "profile gets no symlinks" "" "$(ls -A "$HOME/.codex-profiles/cx")"

"$T/wrap/codex" --login_new 'bad/name' >/dev/null 2>&1; check "invalid name rejected" "1" "$?"

# installer refuses to clobber a real regular-file binary at the target path
mkdir -p "$T/bin2"; cp "$T/real/codex" "$T/bin2/codex"
PATH="$T/bin2:$PATH" "$ROOT/install.sh" "$T/bin2" >/dev/null 2>&1; check "installer refuses to overwrite real binary" "1" "$?"
check "real binary intact" "yes" "$(grep -q 'ARGS=' "$T/bin2/codex" && echo yes)"
PATH="$T/bin2:$PATH" "$ROOT/install.sh" "$T/wrapdir" >/dev/null 2>&1; check "installer into separate dir" "0" "$?"
check "real-bin recorded" "$T/bin2/codex" "$(<"$T/wrapdir/.codex-real-bin")"
PATH="$T/bin2:$PATH" "$ROOT/install.sh" --uninstall "$T/wrapdir" >/dev/null 2>&1
check "uninstall removes wrapper" "no" "$([[ -e "$T/wrapdir/codex" ]] && echo yes || echo no)"

exit $fail
