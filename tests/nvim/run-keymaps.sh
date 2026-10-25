#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
config=${KEYMAP_TEST_CONFIG:-$repo/home/dot_config/nvim}
config=$(CDPATH= cd -- "$config" && pwd)
plugins=${1:-${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy}
if ! command -v nvim >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1 || ! test -d "$plugins/neo-tree.nvim"; then
  printf '%s\n' 'SKIP: Neovim, Git and an existing selected-plugin cache are required' >&2
  exit 77
fi
plugins=$(CDPATH= cd -- "$plugins" && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/nvim-keymaps.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
mkdir -p "$scratch/config" "$scratch/cache" "$scratch/data" "$scratch/state" "$scratch/tmp" "$scratch/files"
ln -s "$config" "$scratch/config/nvim"
for name in alpha beta gamma; do printf '%s\n' "$name" > "$scratch/files/$name.txt"; done
fixture_git() {
  env -i PATH="$PATH" HOME="$scratch" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git -C "$scratch/files" -c core.hooksPath=/dev/null "$@"
}
fixture_git init -q
fixture_git add alpha.txt beta.txt gamma.txt
fixture_git -c user.name=KeymapTest -c user.email=keymap@example.invalid \
  -c commit.gpgsign=false commit -qm 'Create keymap fixture'
printf '%s\n' changed > "$scratch/files/alpha.txt"
env -i PATH="$PATH" HOME="$scratch" TMPDIR="$scratch/tmp" \
  XDG_CONFIG_HOME="$scratch/config" XDG_CACHE_HOME="$scratch/cache" \
  XDG_DATA_HOME="$scratch/data" XDG_STATE_HOME="$scratch/state" \
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 SHELL=/bin/sh \
  GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0 \
  NVIM_LOG_FILE="$scratch/nvim.log" KEYMAP_TEST_FILES="$scratch/files" KEYMAP_TEST_RESULT="$scratch/result" \
  KEYMAP_TEST_CONFIG="$config" KEYMAP_TEST_SCRIPT="$repo/tests/nvim/keymaps.lua" KEYMAP_TEST_PLUGINS="$plugins" \
  nvim --headless -u NONE -i NONE -l "$repo/tests/nvim/native.lua"
test -s "$scratch/result"
