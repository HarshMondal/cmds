# output-marker — show a faint '↳' where a command's output begins, but only
# when the command actually prints something. Unlike the marker built into the
# `cmds` picker, this is shell-wide: it wraps EVERY command you run at the prompt.
#
# It works by hooking bash's command cycle: a DEBUG trap fires just before each
# command (print the marker, remember where the cursor is), and PROMPT_COMMAND
# fires just after (if the cursor never moved, nothing was printed, so erase the
# marker again). Output is never captured or piped, so `cd`, `source`, streaming
# servers and full-screen apps keep working with the live shell and real TTY.
#
# Source this AFTER your prompt is set up (it appends to PROMPT_COMMAND):
#   [ -f .../output-marker.bash ] && source .../output-marker.bash

# Echo the cursor position as "row col" via a DSR query (ESC[6n), or fail quietly
# if the terminal doesn't answer — the timeout means it can never hang the shell.
__om_cursor_pos() {
  local reply row col to=0.2
  [ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || to=1
  IFS='[;' read -rsp $'\033[6n' -d R -t "$to" -a reply < /dev/tty || return 1
  row="${reply[1]}"; col="${reply[2]}"
  case "${row}-${col}" in *[!0-9-]*|-*|*-|'') return 1 ;; esac
  printf '%s %s\n' "$row" "$col"
}

__om_armed=
__om_start=

# Before each command: print the marker once and record the cursor position.
__om_preexec() {
  [ -n "$__om_armed" ] || return 0           # only the first command of the line
  [ -z "${COMP_LINE:-}" ] || return 0        # not during tab-completion
  [ -t 1 ] && [ -r /dev/tty ] && [ -w /dev/tty ] || return 0
  case "$BASH_COMMAND" in
    cmds|cmds\ *) return 0 ;;                 # the cmds picker prints its own marker
  esac
  __om_armed=
  local w=${COLUMNS:-80} line
  printf -v line '%*s' "$w" ''        # w spaces ...
  printf '\033[38;5;242m%s\033[0m\n' "${line// /─}"   # ... rendered as a dim divider
  __om_start="$(__om_cursor_pos)"
  return 0
}

# Before each prompt: erase the marker if the cursor never moved (no output).
__om_precmd() {
  local rc=$?
  if [ -n "$__om_start" ]; then
    local now; now="$(__om_cursor_pos)"
    [ "$now" = "$__om_start" ] && printf '\033[1A\033[2K\r'
    __om_start=
  fi
  __om_armed=1
  return "$rc"
}

trap '__om_preexec' DEBUG
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }__om_precmd"
