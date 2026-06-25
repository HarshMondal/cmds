# cmds

**A project-aware terminal command picker.** Run `cmds` inside a project, fuzzy-pick one
of that project's saved commands, and it lands on your prompt line — **editable, not
executed**. Tweak it (add a flag, change a port), press Enter, and *then* it runs.

```
~/Documents/backend-api $ cmds

  cmds> █
❯ uvicorn app.main:app --reload
       dev server
  source .venv/bin/activate
       activate venv
  pytest
       run tests

# pick uvicorn → it appears on your prompt, ready to edit:
~/Documents/backend-api $ uvicorn app.main:app --reload --port 8001
#                          └ edit freely, then press Enter to run
```

No more digging through shell history or the README to remember the exact venv path,
module name, or flags for *this* project.

## Why two Enters?

1. **First Enter** — selects the command and inserts it onto your prompt.
2. **Second Enter** — runs it (after any edits you make).

Selection and execution are deliberately separate, so you never accidentally run
something, and you're always free to adjust it first.

## How it works

A subprocess can't type into its parent shell's prompt. So `cmds` is a small **bash
function** (sourced into `~/.bashrc`) wrapping a helper binary `cmds-core`:

- `cmds-core` reads/writes the command store and runs the [`fzf`](https://github.com/junegunn/fzf) picker.
- the `cmds` function takes the picked command and uses readline (`read -e -i`) to place
  it on an editable prompt line, then runs it on your Enter.

This is the same shell-integration pattern that `fzf`, `zoxide`, and `mcfly` use.

## Requirements

- **bash** (4+)
- **[fzf](https://github.com/junegunn/fzf)** — the interactive picker (fzf ≥ 0.53 shows
  the title on a second line; older versions fall back to one line per command)
- **[jq](https://stedolan.github.io/jq/)** — JSON storage

```sh
# Debian/Ubuntu
sudo apt install fzf jq
# Fedora
sudo dnf install fzf jq
# macOS
brew install fzf jq
```

## Install

```sh
git clone <this-repo> cmds && cd cmds
./install.sh
source ~/.bashrc        # or open a new terminal
```

`install.sh` copies `cmds-core` to `~/.local/bin/`, the shell function to
`~/.config/cmds/`, and adds one guarded line to `~/.bashrc`. It never auto-installs
dependencies and never overwrites your saved commands.

## Usage

| Command | What it does |
| --- | --- |
| `cmds` | Open the picker for the current directory; selection → editable prompt line |
| `cmds add '<cmd>' -t '<title>'` | Save a command with a friendly title |
| `cmds add` | Save the command you **just ran** (then prompts for an optional title) |
| `cmds list` | List this directory's commands |
| `cmds edit` | Pick a command → edit its command, edit its title, or delete it |
| `cmds edit --raw` | Open the JSON store in `$EDITOR` |
| `cmds rm` | Pick a command to delete |
| `cmds projects` | List every directory that has saved commands |
| `cmds help` | Show help |

### Adding commands

Two ways, both manual (the tool never guesses commands for you):

```sh
# Explicit:
cmds add 'uvicorn app.main:app --reload' -t 'dev server'

# Quick-add — run something that works, then remember it forever:
uvicorn app.main:app --reload
cmds add                 # grabs the previous command, shows it prefilled to
                         # confirm/edit, then asks for an optional title
```

### Editing commands

```sh
cmds edit
# → pick a command from the list
# → choose: [c] edit command   [t] edit title   [d] delete
# → the current value is prefilled for you to edit inline
```

## Where data lives

One central JSON file, keyed by the **exact** directory you were in when you saved each
command — nothing is ever written into your project folders:

```
~/.config/cmds/commands.json        (honors $XDG_CONFIG_HOME)
```

```json
{
  "/home/you/Documents/backend-api": {
    "commands": [
      { "cmd": "uvicorn app.main:app --reload", "title": "dev server" },
      { "cmd": "pytest", "title": "run tests" }
    ]
  }
}
```

Because the key is the exact directory, run `cmds` from the directory where you saved the
commands (usually the project root).

## Uninstall

```sh
./uninstall.sh            # removes the tool, KEEPS your saved commands
./uninstall.sh --purge    # also deletes ~/.config/cmds/ (asks first)
```

## Troubleshooting

- **`cmds: command not found`** — reload your shell: `source ~/.bashrc`.
- **`cmds-core: command not found`** — `~/.local/bin` isn't on your `PATH`; add it.
- **Empty list / "no commands saved"** — you're in a different directory than where you
  saved them, or you haven't added any yet. Check with `cmds projects`.
- **Titles show on the same line as the command** — your `fzf` is older than 0.53; this
  is the expected fallback. Upgrade fzf for the two-line layout.

## Tests

```sh
shellcheck bin/cmds-core shell/cmds.bash install.sh uninstall.sh
bats tests/
```

## Future ideas

Auto-detection of commands (package.json scripts, Makefile, docker-compose, pyproject),
number-key selection, an optional `Ctrl-G` keybinding, git-root project boundaries,
shareable in-repo `.cmds.toml`, and zsh/fish support.

## License

MIT — see [LICENSE](LICENSE).
