#!/bin/sh
# Fixture scripts expand their variables in the child shell.
# shellcheck disable=SC2016
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
home="$tmp/home"
state="$home/.local/share/dotfiles/sheldon"
generation="$state/generations/generation.test"
repos="$generation/repos/github.com"
mkdir -p "$repos/ohmyzsh/ohmyzsh/plugins/extract" \
    "$repos/scop/bash-completion" "$repos/lincheney/fzf-tab-completion/bash" "$tmp/bin"
printf '%s\n' generation.test > "$state/current"
printf '%s\n' 'print -r -- loaded-generation >> "$TEST_LOG"' > "$generation/zsh-plugins.zsh"
printf '%s\n' 'extract() { print -r -- "$1" > "$TEST_EXTRACT_LOG"; }' \
    > "$repos/ohmyzsh/ohmyzsh/plugins/extract/extract.plugin.zsh"
printf '%s\n' 'printf "completion loaded\n" >> "$TEST_LOG"' \
    > "$repos/scop/bash-completion/bash_completion"
printf '%s\n' 'fzf_bash_completion() { printf "selected\n"; }' \
    > "$repos/lincheney/fzf-tab-completion/bash/fzf-bash-completion.sh"
printf '%s\n' '#!/bin/sh' 'printf "shortcut loaded\n" >> "$TEST_LOG"' > "$tmp/bin/fzf"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$tmp/bin/tac"
printf '%s\n' '#!/bin/sh' 'printf "Linux\n"' > "$tmp/bin/uname"
chmod +x "$tmp/bin/fzf" "$tmp/bin/tac" "$tmp/bin/uname"

paths="$repo/home/private_dot_config/private_shell/generation.sh"
zsh_plugins="$repo/home/private_dot_config/private_shell/zsh/plugins.zsh"
common="$repo/home/private_dot_config/private_shell/preferences.sh"
bash_completion="$repo/home/private_dot_config/private_shell/bash/completion.sh"
export HOME="$home" PATH="$tmp/bin:/usr/bin:/bin" TERM=dumb
export TEST_LOG="$tmp/log" TEST_EXTRACT_LOG="$tmp/extract-log"
export PATHS="$paths" ZSH_PLUGINS="$zsh_plugins" COMMON="$common" BASH_COMPLETION="$bash_completion"

: > "$TEST_LOG"
zsh -fic '. "$PATHS"; . "$ZSH_PLUGINS"' 2>/dev/null
printf 'shortcut loaded\nloaded-generation\n' > "$tmp/expected"
diff -u "$tmp/expected" "$TEST_LOG"

if [ -x /opt/homebrew/bin/bash ]; then
    : > "$TEST_LOG"
    /opt/homebrew/bin/bash --noprofile --norc -ic \
        '. "$PATHS"; . "$BASH_COMPLETION"; fzf_bash_completion' > "$tmp/result" 2>/dev/null
    grep -q '^completion loaded$' "$TEST_LOG"
    grep -q '^selected$' "$tmp/result"
fi

/bin/bash --noprofile --norc -c '. "$PATHS"; . "$COMMON"; extract "archive with spaces.tar.gz"'
[ "$(cat "$TEST_EXTRACT_LOG")" = 'archive with spaces.tar.gz' ]

printf '%s\n' '../outside' > "$state/current"
zsh -fc '. "$PATHS"; [ -z "$_dotfiles_generation_dir" ]'

printf 'Sheldon generation startup tests passed\n'
