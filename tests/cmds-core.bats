#!/usr/bin/env bats
#
# Unit tests for cmds-core's non-interactive logic (storage, add, list,
# projects, dedup, JSON validity). The fzf-driven flows (pick/edit/rm) are
# interactive and are covered by the manual end-to-end checks in the README.
#
# Run with:  bats tests/

setup() {
  TMP="$(mktemp -d)"
  export XDG_CONFIG_HOME="$TMP/config"
  export HOME="$TMP/home"
  mkdir -p "$HOME"
  CORE="${BATS_TEST_DIRNAME}/../bin/cmds-core"
  STORE="$XDG_CONFIG_HOME/cmds/commands.json"

  WORK="$TMP/proj"
  mkdir -p "$WORK"
  cd "$WORK"
  WORK="$(pwd -P)"   # match the key cmds-core stores (pwd -P)
}

teardown() {
  rm -rf "$TMP"
}

@test "add stores command and title" {
  run "$CORE" add 'pytest' -t 'run tests'
  [ "$status" -eq 0 ]

  run "$CORE" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"pytest"* ]]
  [[ "$output" == *"run tests"* ]]
}

@test "add without title stores empty title" {
  "$CORE" add 'npm run dev'
  run jq -r --arg k "$WORK" '.[$k].commands[0].title' "$STORE"
  [ "$output" = "" ]
}

@test "duplicate add is a no-op" {
  "$CORE" add 'pytest'
  "$CORE" add 'pytest'
  run jq -r --arg k "$WORK" '.[$k].commands | length' "$STORE"
  [ "$output" -eq 1 ]
}

@test "list fails when no commands for this dir" {
  run "$CORE" list
  [ "$status" -ne 0 ]
}

@test "two dirs keep separate command sets" {
  "$CORE" add 'a'
  local other="$TMP/other"
  mkdir -p "$other"
  ( cd "$other" && "$CORE" add 'b' )
  run jq -r --arg k "$WORK" '.[$k].commands | length' "$STORE"
  [ "$output" -eq 1 ]
  run jq -r 'keys | length' "$STORE"
  [ "$output" -eq 2 ]
}

@test "projects reports the directory and count" {
  "$CORE" add 'a'
  "$CORE" add 'b'
  run "$CORE" projects
  [ "$status" -eq 0 ]
  [[ "$output" == *"$WORK"* ]]
  [[ "$output" == *"2"* ]]
}

@test "store remains valid json after writes" {
  "$CORE" add 'a' -t 'x'
  "$CORE" add 'b'
  run jq -e . "$STORE"
  [ "$status" -eq 0 ]
}

@test "add rejects an empty command" {
  run "$CORE" add ''
  [ "$status" -ne 0 ]
}
