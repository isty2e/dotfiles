#!/bin/sh
# Single-quoted snippets are expanded by the child Zsh, not the test shell.
# shellcheck disable=SC2016
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/home" "$tmp/zdotdir"

options="$repo/home/dot_zshrc"
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
proc expect_zsh_output {session output stage} {
    expect -i $session -timeout 5 \
        -exact $output {} \
        timeout { puts stderr "Timed out waiting for $stage"; exit 1 } \
        eof { puts stderr "Zsh exited while waiting for $stage"; exit 1 }
}

spawn -noecho /bin/zsh -d -i
set writer $spawn_id
expect_zsh_output $writer "TEST_PROMPT> " "writer startup"
send -i $writer "echo dotfiles_shared_history\r"
expect_zsh_output $writer "\r\ndotfiles_shared_history\r\n" "writer command output"
expect_zsh_output $writer "TEST_PROMPT> " "writer command completion"

spawn -noecho /bin/zsh -d -i
set reader $spawn_id
expect_zsh_output $reader "TEST_PROMPT> " "reader startup"
send -i $reader "fc -l 1\r"
expect_zsh_output $reader "echo dotfiles_shared_history" "shared history"

foreach session [list $writer $reader] {
    send -i $session "exit\r"
    expect -i $session -timeout 5 {
        eof {}
        timeout { puts stderr "Zsh did not exit"; exit 1 }
    }
    wait -i $session
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
