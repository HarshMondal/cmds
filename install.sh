#!/usr/bin/env bash
#
# install.sh — install cmds for the current user. Idempotent; safe to re-run.
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cmds"
BASHRC="$HOME/.bashrc"
MARK_BEGIN="# >>> cmds >>>"
MARK_END="# <<< cmds <<<"

info() { printf '  %s\n' "$1"; }
err()  { printf 'error: %s\n' "$1" >&2; }

echo "Installing cmds…"

# 1. dependencies — never auto-install, just tell the user how.
missing=()
for dep in bash fzf jq; do
  command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
done
if [ "${#missing[@]}" -gt 0 ]; then
  err "missing dependencies: ${missing[*]}"
  info "Debian/Ubuntu:  sudo apt install ${missing[*]}"
  info "Fedora:         sudo dnf install ${missing[*]}"
  info "macOS (brew):   brew install ${missing[*]}"
  exit 1
fi

# 2. the cmds-core executable
mkdir -p "$BIN_DIR"
install -m 0755 "$SRC_DIR/bin/cmds-core" "$BIN_DIR/cmds-core"
info "installed $BIN_DIR/cmds-core"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) info "note: $BIN_DIR is not on your PATH — add it (e.g. in ~/.bashrc)" ;;
esac

# 3. the shell integration
mkdir -p "$CFG_DIR"
install -m 0644 "$SRC_DIR/shell/cmds.bash" "$CFG_DIR/cmds.bash"
info "installed $CFG_DIR/cmds.bash"

# 4. wire it into ~/.bashrc (guarded block, only once)
if [ -f "$BASHRC" ] && grep -qF "$MARK_BEGIN" "$BASHRC"; then
  info "~/.bashrc already configured"
else
  {
    printf '\n%s\n' "$MARK_BEGIN"
    printf '[ -f "%s/cmds.bash" ] && source "%s/cmds.bash"\n' "$CFG_DIR" "$CFG_DIR"
    printf '%s\n' "$MARK_END"
  } >> "$BASHRC"
  info "added source line to ~/.bashrc"
fi

# 5. data store — never clobber existing data
[ -f "$CFG_DIR/commands.json" ] || printf '{}\n' > "$CFG_DIR/commands.json"

echo
echo "Done. Run 'source ~/.bashrc' (or open a new terminal), then try:"
echo "    cd into a project, run:  cmds add 'echo hello' -t demo"
echo "    then:                    cmds"
