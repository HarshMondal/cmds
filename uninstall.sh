#!/usr/bin/env bash
#
# uninstall.sh — remove cmds. Keeps your saved commands unless --purge is given.
#
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cmds"
BASHRC="$HOME/.bashrc"
MARK_BEGIN="# >>> cmds >>>"
MARK_END="# <<< cmds <<<"

purge=0
[ "${1:-}" = "--purge" ] && purge=1

info() { printf '  %s\n' "$1"; }

echo "Uninstalling cmds…"

# 1. remove the guarded block from ~/.bashrc
if [ -f "$BASHRC" ] && grep -qF "$MARK_BEGIN" "$BASHRC"; then
  tmp="$(mktemp)"
  sed "/^${MARK_BEGIN}\$/,/^${MARK_END}\$/d" "$BASHRC" > "$tmp"
  mv -f "$tmp" "$BASHRC"
  info "removed block from ~/.bashrc"
fi

# 2. remove installed files (only report what actually existed)
if [ -e "$BIN_DIR/cmds-core" ]; then rm -f "$BIN_DIR/cmds-core"; info "removed $BIN_DIR/cmds-core"; fi
if [ -e "$CFG_DIR/cmds.bash" ]; then rm -f "$CFG_DIR/cmds.bash"; info "removed $CFG_DIR/cmds.bash"; fi

# 3. data
if [ "$purge" -eq 1 ]; then
  read -r -p "Delete saved commands ($CFG_DIR/commands.json)? [y/N] " ans
  case "$ans" in
    y|Y)
      rm -rf "$CFG_DIR"
      info "purged $CFG_DIR" ;;
    *)
      info "kept your saved commands" ;;
  esac
else
  info "kept your saved commands ($CFG_DIR/commands.json) — pass --purge to remove"
fi

echo "Done. Run 'source ~/.bashrc' or open a new terminal to finish."
