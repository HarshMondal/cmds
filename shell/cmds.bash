# cmds — shell integration for bash.
#
# Source this from your ~/.bashrc:
#   [ -f ~/.config/cmds/cmds.bash ] && source ~/.config/cmds/cmds.bash
#
# `cmds` MUST be a shell function (not just the cmds-core binary): only code
# running in your interactive shell can place text onto the prompt line for you
# to edit before running it. The heavy lifting lives in `cmds-core`.

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
      eval "$edited"
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
