#!/usr/bin/env bash
# Installs the codex --login_new wrapper.
#
# Usage:
#   ./install.sh [dir]               # default dir: ~/.local/bin
#   ./install.sh --uninstall [dir]
#
# Safety: if the real `codex` is a plain file at the target path, installing
# the wrapper there would overwrite it, so this script refuses and asks for a
# different directory that comes earlier on PATH.

set -euo pipefail

TOOL="codex"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/bin/$TOOL"

uninstall=false
if [[ "${1:-}" == "--uninstall" ]]; then uninstall=true; shift; fi
INSTALL_DIR="${1:-$HOME/.local/bin}"
TARGET_FILE="$INSTALL_DIR/$TOOL"

if [[ "$uninstall" == true ]]; then
  if [[ -f "$TARGET_FILE" ]] && cmp -s "$TARGET_FILE" "$SOURCE_FILE"; then
    rm -f "$TARGET_FILE" "$INSTALL_DIR/.$TOOL-real-bin"
    echo "Removed $TARGET_FILE"
  else
    echo "Nothing to remove at $TARGET_FILE (missing, or not this wrapper)"
  fi
  exit 0
fi

[[ -f "$SOURCE_FILE" ]] || { echo "error: $SOURCE_FILE not found" >&2; exit 1; }
mkdir -p "$INSTALL_DIR"

# Find the real binary BEFORE touching anything: first PATH match that is not
# a copy of this wrapper (detected by its header line).
real=""
IFS=:
for dir in $PATH; do
  c="$dir/$TOOL"
  if [[ -x "$c" ]] && ! head -c 600 "$c" 2>/dev/null | grep -q -- 'add a --login_new <profile> flag'; then
    real="$c"
    break
  fi
done
unset IFS
if [[ -z "$real" ]]; then
  echo "error: no real $TOOL found on PATH; install $TOOL first, then re-run." >&2
  exit 1
fi

# Refuse to clobber the real binary if it IS the target path.
if [[ -e "$TARGET_FILE" && ! -L "$TARGET_FILE" ]] && ! cmp -s "$TARGET_FILE" "$SOURCE_FILE" \
   && [[ "$(readlink -f "$TARGET_FILE")" == "$(readlink -f "$real")" ]]; then
  echo "error: $TARGET_FILE is the real $TOOL binary; installing there would overwrite it." >&2
  echo "       Re-run with a different dir that is EARLIER on PATH, e.g.:" >&2
  echo "         mkdir -p ~/bin-wrappers && $0 ~/bin-wrappers" >&2
  echo "         export PATH=\"\$HOME/bin-wrappers:\$PATH\"" >&2
  exit 1
fi

rm -f "$TARGET_FILE"
cp "$SOURCE_FILE" "$TARGET_FILE"
chmod +x "$TARGET_FILE"
printf '%s\n' "$real" > "$INSTALL_DIR/.$TOOL-real-bin"
echo "Installed wrapper to $TARGET_FILE (wrapping $real)"

resolved="$(command -v "$TOOL" || true)"
if [[ "$(readlink -f "${resolved:-/nonexistent}")" != "$(readlink -f "$TARGET_FILE")" ]]; then
  echo "warning: '$TOOL' on your PATH resolves to ${resolved:-nothing}, not the wrapper." >&2
  echo "         Put '$INSTALL_DIR' earlier in PATH: export PATH=\"$INSTALL_DIR:\$PATH\"" >&2
else
  echo "Verified: '$TOOL' now resolves to the wrapper."
fi
