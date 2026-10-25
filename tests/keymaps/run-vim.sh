#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
runtime=${VIM_TEST_RUNTIME:-$HOME/.vim}
binary=${VIM_TEST_BINARY:-vim}
if ! command -v "$binary" >/dev/null 2>&1 || ! test -f "$runtime/autoload/plug.vim" || ! test -d "$runtime/plugged/nerdtree"; then
  printf '%s\n' 'SKIP: actual Vim and an existing vim-plug/NERDTree runtime are required' >&2
  exit 77
fi
runtime=$(CDPATH= cd -- "$runtime" && pwd)
if ! test -t 0 || ! test -t 1; then
  printf '%s\n' 'SKIP: run the full plugin-loaded Vim suite in a terminal, not Ex mode' >&2
  exit 77
fi
scratch=$(mktemp -d "${TMPDIR:-/tmp}/vim-keymaps.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
mkdir -p "$scratch/.vim" "$scratch/files" "$scratch/config" "$scratch/cache" "$scratch/data" "$scratch/state" "$scratch/tmp"
for name in autoload plugged colors; do
  if test -d "$runtime/$name"; then ln -s "$runtime/$name" "$scratch/.vim/$name"; fi
done
for name in alpha beta gamma; do printf '%s\n' "$name" > "$scratch/files/$name.txt"; done
env -i PATH="$PATH" HOME="$scratch" TMPDIR="$scratch/tmp" TERM="${TERM:-xterm-256color}" \
  XDG_CONFIG_HOME="$scratch/config" XDG_CACHE_HOME="$scratch/cache" \
  XDG_DATA_HOME="$scratch/data" XDG_STATE_HOME="$scratch/state" \
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 SHELL=/bin/sh \
  KEYMAP_TEST_FILES="$scratch/files" KEYMAP_TEST_SCRIPT="$repo/tests/keymaps/vim.vim" KEYMAP_TEST_RESULT="$scratch/result" \
  "$binary" -Nu "$repo/home/dot_vimrc" -n -i NONE \
  -c 'autocmd VimEnter * ++once execute "source " . fnameescape($KEYMAP_TEST_SCRIPT)'
test -s "$scratch/result"
printf '%s\n' 'PASS: plugin-loaded Vim keymap suite completed'
