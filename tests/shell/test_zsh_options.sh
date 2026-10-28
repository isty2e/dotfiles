#!/bin/sh
# Single-quoted snippets are expanded by the child Zsh, not the test shell.
# shellcheck disable=SC2016
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/home" "$tmp/zdotdir"

options="$repo/home/private_dot_config/dotfiles/shell/zsh-options.zsh"
env -i HOME="$tmp/home" PATH=/usr/bin:/bin TERM=xterm ZSH_OPTIONS="$options" zsh -fic '
    . "$ZSH_OPTIONS"
    [[ $HISTFILE == "$HOME/.zsh_history" && $SAVEHIST == $HISTSIZE ]] || exit 1
    [[ -o sharehistory && -o autocd && ! -o correct ]] || exit 1
    print -s dotfiles_zsh_history_entry
    fc -AI
    grep -q dotfiles_zsh_history_entry "$HISTFILE"
' 2>/dev/null

if command -v expect >/dev/null 2>&1; then
    printf '%s\n' '. "$ZSH_OPTIONS"' 'PROMPT="TEST_PROMPT> "' > "$tmp/zdotdir/.zshrc"
    cat > "$tmp/history.exp" <<'EOF'
set timeout 5
spawn -noecho /bin/zsh -i
expect "TEST_PROMPT> "
send "echo dotfiles_shared_history\r"
expect "TEST_PROMPT> "
spawn -noecho /bin/zsh -i
expect "TEST_PROMPT> "
send "fc -l 1\r"
expect {
    "echo dotfiles_shared_history" {}
    timeout { exit 1 }
    eof { exit 1 }
}
EOF
    env -i HOME="$tmp/home" ZDOTDIR="$tmp/zdotdir" PATH=/usr/bin:/bin TERM=xterm \
        ZSH_OPTIONS="$options" expect "$tmp/history.exp" > "$tmp/history.log" 2>&1 || {
        cat "$tmp/history.log" >&2
        exit 1
    }
else
    printf 'Skipping interactive history test: expect is not installed\n' >&2
fi

printf 'Zsh options and history tests passed\n'
