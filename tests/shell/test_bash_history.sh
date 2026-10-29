#!/bin/sh
# Single-quoted snippets are expanded by the child Bash, not the test shell.
# shellcheck disable=SC2016
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/home" "$tmp/bin"
fragment="$repo/home/private_dot_config/private_dotfiles/shell/bash/history.sh"

cat > "$tmp/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "$TEST_PLATFORM"
EOF
chmod +x "$tmp/bin/uname"

cat > "$tmp/rc" <<'EOF'
PS1='TEST_PROMPT> '
. "$FRAGMENT"
EOF
cat > "$tmp/history.exp" <<'EOF'
set timeout 5
spawn -noecho $env(TEST_SHELL) --noprofile --rcfile $env(TEST_RC) -i
set first $spawn_id
expect "TEST_PROMPT> "
spawn -noecho $env(TEST_SHELL) --noprofile --rcfile $env(TEST_RC) -i
set second $spawn_id
expect "TEST_PROMPT> "
send -i $first "echo dotfiles_shared_history\r"
expect -i $first "TEST_PROMPT> "
send -i $second ":\r"
expect -i $second "TEST_PROMPT> "
send -i $second "history\r"
expect -i $second {
    "echo dotfiles_shared_history" {}
    timeout { exit 1 }
    eof { exit 1 }
}
send -i $first "exit\r"
expect -i $first eof
send -i $second "exit\r"
expect -i $second eof
EOF

for shell in /bin/bash /opt/homebrew/bin/bash; do
    [ -x "$shell" ] || continue
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm FRAGMENT="$fragment" TEST_PLATFORM=Darwin DOTFILES_BASH_HISTORY_SYNC=1 \
        "$shell" --noprofile --norc -ic '
            PROMPT_COMMAND="printf existing"
            . "$FRAGMENT"
            . "$FRAGMENT"
            [[ $PROMPT_COMMAND == "printf existing;_dotfiles_history_sync" ]] || exit 1
            [[ $HISTCONTROL == ignoreboth && $HISTSIZE == 1000 && $HISTFILESIZE == 2000 ]]
        ' 2>/dev/null

    major=$($shell --noprofile --norc -c 'printf %s "${BASH_VERSINFO[0]}"')
    if [ "$major" -ge 5 ]; then
        env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm FRAGMENT="$fragment" TEST_PLATFORM=Darwin DOTFILES_BASH_HISTORY_SYNC=1 \
            "$shell" --noprofile --norc -ic '
                PROMPT_COMMAND=("printf existing")
                . "$FRAGMENT"
                . "$FRAGMENT"
                [[ ${#PROMPT_COMMAND[@]} == 2 && ${PROMPT_COMMAND[0]} == "printf existing" && ${PROMPT_COMMAND[1]} == _dotfiles_history_sync ]]
            ' 2>/dev/null
    fi

    if command -v expect >/dev/null 2>&1; then
        # Bash 3.2's history -a does not append to a fresh, empty history file.
        printf 'echo previous_session\n' > "$tmp/home/.bash_history"
        env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm FRAGMENT="$fragment" TEST_PLATFORM=Darwin DOTFILES_BASH_HISTORY_SYNC=1 \
            BASH_SILENCE_DEPRECATION_WARNING=1 TEST_SHELL="$shell" TEST_RC="$tmp/rc" \
            expect "$tmp/history.exp" > /dev/null
    else
        printf 'Skipping interactive history test: expect is not installed\n' >&2
    fi

    output=$(env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm \
        FRAGMENT="$fragment" TEST_PLATFORM=Linux DOTFILES_BASH_HISTORY_SYNC=0 "$shell" --noprofile --norc -ic '
            PROMPT_COMMAND="printf existing"
            history() { printf unexpected; }
            . "$FRAGMENT"
            . "$FRAGMENT"
            eval "$PROMPT_COMMAND"
        ' 2>/dev/null)
    [ "$output" = existing ]

    if [ "$major" -ge 5 ]; then
        output=$(env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm \
            FRAGMENT="$fragment" TEST_PLATFORM=Linux DOTFILES_BASH_HISTORY_SYNC=0 "$shell" --noprofile --norc -ic '
                PROMPT_COMMAND=("printf existing")
                history() { printf unexpected; }
                . "$FRAGMENT"
                . "$FRAGMENT"
                for command in "${PROMPT_COMMAND[@]}"; do eval "$command"; done
            ' 2>/dev/null)
        [ "$output" = existing ]
    fi
done

printf 'Bash history configuration tests passed\n'
