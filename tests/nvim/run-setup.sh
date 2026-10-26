#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
binary=$(command -v "${NVIM:-nvim}" || true)
if [ -z "$binary" ]; then
  echo 'SKIP: Neovim is not installed'
  exit 77
fi
native=${LAZY:-${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim}
git=$(command -v git || true)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/nvim-setup.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
mkdir -p "$scratch/home" "$scratch/data" "$scratch/config" "$scratch/cache" "$scratch/state"

run() {
  env -i PATH="$PATH" HOME="$scratch/home" XDG_DATA_HOME="$scratch/data" \
    XDG_CONFIG_HOME="$scratch/config" XDG_CACHE_HOME="$scratch/cache" \
    XDG_STATE_HOME="$scratch/state" TMPDIR="$scratch" SHELL=/bin/sh \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0 \
    NVIM_SETUP_SOURCE="$repo/home/private_dot_config/nvim" NVIM_SETUP_TEST_ROOT="$scratch/$1" \
    NVIM_SETUP_NATIVE_LAZY="$native" NVIM_SETUP_REAL_GIT="$git" \
    "$binary" --headless -u NONE -i NONE -l "$repo/tests/nvim/$2"
}

run unit setup.lua
if [ -n "$git" ] && [ -f "$native/lua/lazy/init.lua" ]; then
  run native native_setup.lua
else
  echo 'SKIP: native integration requires Git and an existing lazy.nvim checkout'
fi
