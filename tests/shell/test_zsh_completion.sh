#!/bin/sh
# Single-quoted snippets are expanded by the child shell.
# shellcheck disable=SC2016
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/home/.config/shell/device" "$tmp/bin" "$tmp/zdotdir"
cp "$repo/home/private_dot_config/private_shell/device.sh" "$tmp/home/.config/shell/device.sh"
config="$repo/home/dot_zshrc"

# Do not inherit the host's plugin paths or weaken compinit's security audit.
completion_fpath=$(env -i HOME="$tmp/home" PATH=/usr/bin:/bin zsh -fc '
    for directory in $fpath; do
        if [[ -r $directory/compinit ]]; then
            print -r -- "$directory"
            exit 0
        fi
    done
    exit 1
')

cat > "$tmp/zdotdir/.zshrc" <<'EOF'
. "$MANAGED_RC"
HISTFILE=/dev/null
SAVEHIST=0
fpath=("$COMPLETION_FPATH")
autoload -Uz compinit
compinit -D
_probe_completion() {
    local -a values=(AlphaBETAItem)
    _describe 'probe values' values
}
probe() { print -r -- "COMPLETED:$1"; }
compdef _probe_completion probe
bindkey -e
PROMPT='COMPLETION> '
RPROMPT=''
EOF

cat > "$tmp/completion.exp" <<'EOF'
proc await_output {output stage} {
    expect -timeout 5 \
        -exact $output {} \
        timeout { puts stderr "Timed out waiting for $stage"; exit 1 } \
        eof { puts stderr "Zsh exited while waiting for $stage"; exit 1 }
}
proc complete_word {word expected} {
    send -- "probe $word\t\r"
    await_output "\r\nCOMPLETED:$expected\r\n" "completion of $word"
    await_output "COMPLETION> " "next prompt"
}
spawn -noecho /bin/zsh -d -i
await_output "COMPLETION> " "startup"
complete_word AlphaBETA AlphaBETAItem
if {$env(TEST_DEVICE) == "yes"} {
    complete_word alphabeta alphabeta
    complete_word AlphxBETAItex AlphxBETAItex
} else {
    # More than two case differences prevent approximate matching masking a
    # missing case matcher. Typo cases separately test the two-error boundary.
    complete_word alphabeta AlphaBETAItem
    complete_word ALPHABETAITEM AlphaBETAItem
    complete_word AlphxBETAItex AlphaBETAItem
    complete_word XlphxBETAItex XlphxBETAItex
}
send -- "exit\r"
expect -timeout 5 eof
set result [wait]
exit [lindex $result 3]
EOF

cat > "$tmp/bin/fd" <<'EOF'
#!/bin/sh
[ "$#" -eq 2 ] && [ "$1" = --type ] && [ "$2" = f ] || exit 2
printf '%s\n' sample.py
EOF
chmod +x "$tmp/bin/fd"

run_completion() {
    if command -v expect >/dev/null 2>&1; then
        env -i HOME="$tmp/home" ZDOTDIR="$tmp/zdotdir" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm \
            MANAGED_RC="$config" COMPLETION_FPATH="$completion_fpath" TEST_DEVICE="$1" \
            expect "$tmp/completion.exp" > "$tmp/completion.log" 2>&1 || {
            cat "$tmp/completion.log" >&2
            exit 1
        }
    else
        printf 'Skipping interactive Zsh completion test: expect is not installed\n' >&2
    fi
}

run_completion no
output=$(env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" MANAGED_RC="$config" zsh -fic '
    . "$MANAGED_RC"
    [[ $ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE == "fg=#808080" && ! -o correct ]] || exit 1
    sh -c '\''eval "$FZF_DEFAULT_COMMAND"'\''
')
[ "$output" = sample.py ]

output=$(env -i HOME="$tmp/home" PATH=/usr/bin:/bin MANAGED_RC="$config" \
    FZF_DEFAULT_COMMAND='printf inherited' ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=fg=cyan zsh -fic '
    . "$MANAGED_RC"
    [[ $ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE == fg=cyan ]] || exit 1
    sh -c '\''eval "$FZF_DEFAULT_COMMAND"'\''
')
[ "$output" = inherited ]

env -i HOME="$tmp/home" PATH=/usr/bin:/bin MANAGED_RC="$config" \
    FZF_DEFAULT_COMMAND= ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE= zsh -fic '
    . "$MANAGED_RC"
    [[ -z $FZF_DEFAULT_COMMAND && -z $ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE ]]
'

cat > "$tmp/home/.config/shell/device/local.sh" <<'EOF'
if [ -n "${ZSH_VERSION:-}" ]; then
    zstyle ':completion:*' matcher-list ''
    zstyle ':completion:*' completer _complete
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=fg=cyan
fi
FZF_DEFAULT_COMMAND='printf device'
EOF
run_completion yes
output=$(env -i HOME="$tmp/home" PATH=/usr/bin:/bin MANAGED_RC="$config" zsh -fic '
    . "$MANAGED_RC"
    [[ $ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE == fg=cyan ]] || exit 1
    sh -c '\''eval "$FZF_DEFAULT_COMMAND"'\''
')
[ "$output" = device ]

printf 'Zsh completion preferences and device override tests passed\n'
