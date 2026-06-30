# cmds — shell integration for bash.
#
# Source this from your ~/.bashrc:
#   [ -f ~/.config/cmds/cmds.bash ] && source ~/.config/cmds/cmds.bash
#
# `cmds` MUST be a shell function (not just the cmds-core binary): only code
# running in your interactive shell can place text onto the prompt line for you
# to edit before running it. The heavy lifting lives in `cmds-core`.

# Echo the terminal cursor position as "row col" via a DSR query (ESC[6n), or
# fail quietly if the terminal doesn't answer — the timeout means it can never
# hang the shell, and callers treat "no answer" as "leave the screen alone".
_cmds_cursor_pos() {
  local reply row col to=0.2
  [ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || to=1   # fractional read -t needs bash 4+
  # Send the query as read's prompt so echo is already off (-s) when the reply
  # arrives — otherwise the ESC[row;colR reply can leak onto the screen.
  IFS='[;' read -rsp $'\033[6n' -d R -t "$to" -a reply < /dev/tty || return 1
  row="${reply[1]}"; col="${reply[2]}"
  case "${row}-${col}" in *[!0-9-]*|-*|*-|'') return 1 ;; esac
  printf '%s %s\n' "$row" "$col"
}

cmds() {
  case "${1:-}" in
    "")
      # Picker flow: pick a command, drop it onto an editable prompt line,
      # then run it only when YOU press Enter (selection != execution).
      local sel edited
      sel="$(cmds-core pick)" || return
      [ -n "$sel" ] || return
      # read -e -i gives a readline-editable line prefilled with the command.
      IFS= read -r -e -i "$sel" -p '› ' edited || return
      [ -n "$edited" ] || return
      history -s "$edited"   # so Up-arrow recalls what you just ran

      # Mark where output begins with a dim divider, but only when there IS
      # output. We can't capture eval's output (that would break `source`/`cd`,
      # streaming servers, and TUIs, which all need the live shell and real TTY),
      # so instead we print the marker, then erase it again if the cursor never moved.
      local _cmds_rc
      if [ -t 1 ] && [ -r /dev/tty ] && [ -w /dev/tty ]; then
        local _start _end _srow _scol _erow _ecol _w _line
        _w=${COLUMNS:-80}; printf -v _line '%*s' "$_w" ''
        printf '\033[38;5;242m%s\033[0m\n' "${_line// /─}"
        _start="$(_cmds_cursor_pos)"
        eval "$edited"; _cmds_rc=$?
        _end="$(_cmds_cursor_pos)"
        if [ -n "$_start" ] && [ -n "$_end" ]; then
          read -r _srow _scol <<<"$_start"
          read -r _erow _ecol <<<"$_end"
          if [ "$_erow" = "$_srow" ] && [ "$_ecol" = "$_scol" ]; then
            printf '\033[1A\033[2K\r'        # no output => clear the marker
          fi
        fi
      else
        eval "$edited"; _cmds_rc=$?
      fi
      return "$_cmds_rc"
      ;;
    add)
      shift
      if [ "$#" -eq 0 ]; then
        # Quick-add: grab the most recent *real* command and save it.
        # By the time this function runs, bash has already pushed `cmds add`
        # itself onto the history, so we can't just take `fc -ln -1`. Instead we
        # scan the recent history, drop any `cmds ...` lines, and take the last
        # remaining command — then show it prefilled so you can confirm or edit
        # it before it's saved.
        local last title
        local HISTTIMEFORMAT=   # keep fc output free of timestamps
        last="$(fc -ln -16 -1 2>/dev/null \
                | sed -E 's/^[[:space:]]+//' \
                | grep -vE '^cmds([[:space:]]|$)' \
                | tail -n1)"
        if [ -z "$last" ]; then
          printf 'cmds: no recent command found to add\n' >&2
          return 1
        fi
        IFS= read -r -e -i "$last" -p 'add command: ' last || return
        [ -n "$last" ] || return
        read -r -p 'title (optional): ' title
        if [ -n "$title" ]; then
          cmds-core add "$last" -t "$title"
        else
          cmds-core add "$last"
        fi
      else
        cmds-core add "$@"   # cmds add '<cmd>' -t '<title>'
      fi
      ;;
    *)
      # list | edit | rm | projects | help | version
      cmds-core "$@"
      ;;
  esac
}
