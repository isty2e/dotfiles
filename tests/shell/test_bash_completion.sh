#!/bin/sh
# Single-quoted commands are deliberately expanded by the child Bash process.
# shellcheck disable=SC2016
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
generation="$tmp/home/generation"
plugins="$generation/repos/github.com"
mkdir -p "$tmp/bin" "$plugins/scop/bash-completion" "$plugins/lincheney/fzf-tab-completion/bash"

cat > "$tmp/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "$TEST_PLATFORM"
EOF
cat > "$tmp/bin/fzf" <<'EOF'
#!/bin/sh
[ "$1" = --bash ] || exit 1
[ "$MISE_NOT_FOUND_AUTO_INSTALL" = false ] || exit 1
[ "$MISE_AUTO_INSTALL" = false ] || exit 1
printf '%s\n' 'printf "fzf shortcuts loaded\n" >> "$TEST_LOG"'
EOF
cat > "$tmp/bin/tac" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$tmp/bin/"*
printf '%s\n' 'printf "completion loaded\n" >> "$TEST_LOG"' > "$plugins/scop/bash-completion/bash_completion"
cat > "$plugins/lincheney/fzf-tab-completion/bash/fzf-bash-completion.sh" <<'EOF'
printf 'fzf-tab loaded\n' >> "$TEST_LOG"
fzf_bash_completion() { printf 'tab selector invoked\n'; }
EOF

cat > "$tmp/interactive.rc" <<'EOF'
PS1='TEST_PROMPT> '
. "$FRAGMENT"
EOF
cat > "$tmp/check.exp" <<'EOF'
set timeout 5
spawn -noecho $env(TEST_SHELL) --noprofile --rcfile $env(TEST_RC) -i
expect {
    "TEST_PROMPT> " {}
    timeout { exit 1 }
    eof { exit 1 }
}
send "\t"
expect {
    "tab selector invoked" {}
    timeout { exit 1 }
    eof { exit 1 }
}
send "exit\r"
expect {
    eof {}
    timeout { exit 1 }
}
EOF

fragment="$repo/home/private_dot_config/dotfiles/shell/bash-completion.sh"
for shell in /bin/bash /opt/homebrew/bin/bash; do
    [ -x "$shell" ] || continue
    : > "$tmp/log"

    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=dumb _dotfiles_generation_dir="$generation" \
        TEST_PLATFORM=Linux TEST_LOG="$tmp/log" FRAGMENT="$fragment" \
        "$shell" --noprofile --norc -ic '. "$FRAGMENT"' 2>/dev/null

    major=$($shell --noprofile --norc -c 'printf %s "${BASH_VERSINFO[0]}"')
    minor=$($shell --noprofile --norc -c 'printf %s "${BASH_VERSINFO[1]}"')
    if [ "$major" -gt 4 ] || { [ "$major" -eq 4 ] && [ "$minor" -ge 2 ]; }; then
        printf 'fzf shortcuts loaded\ncompletion loaded\nfzf-tab loaded\n' > "$tmp/expected"
        diff -u "$tmp/expected" "$tmp/log"
        if command -v expect >/dev/null 2>&1; then
            env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=dumb _dotfiles_generation_dir="$generation" \
                TEST_PLATFORM=Linux TEST_LOG="$tmp/log" FRAGMENT="$fragment" \
                TEST_SHELL="$shell" TEST_RC="$tmp/interactive.rc" \
                expect "$tmp/check.exp" > /dev/null
        else
            printf 'Skipping interactive Tab test: expect is not installed\n' >&2
        fi
    else
        [ "$(cat "$tmp/log")" = 'fzf shortcuts loaded' ]
    fi

    : > "$tmp/log"
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TEST_PLATFORM=Linux _dotfiles_generation_dir="$generation" \
        TEST_LOG="$tmp/log" FRAGMENT="$fragment" "$shell" --noprofile --norc \
        -c '. "$FRAGMENT"' 2>/dev/null
    [ ! -s "$tmp/log" ]
done

if [ -x /opt/homebrew/bin/bash ]; then
    : > "$tmp/log"
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=dumb \
        TEST_PLATFORM=Linux TEST_LOG="$tmp/log" FRAGMENT="$fragment" \
        /opt/homebrew/bin/bash --noprofile --norc -ic '. "$FRAGMENT"' 2>/dev/null
    [ "$(cat "$tmp/log")" = 'fzf shortcuts loaded' ]
fi

if [ -x /opt/homebrew/bin/bash ]; then
    : > "$tmp/log"
    env -i HOME="$tmp/home" PATH="$tmp/bin" TERM=dumb _dotfiles_generation_dir="$generation" \
        TEST_PLATFORM=Darwin TEST_LOG="$tmp/log" FRAGMENT="$fragment" \
        /opt/homebrew/bin/bash --noprofile --norc -ic '. "$FRAGMENT"' 2>/dev/null
    printf 'fzf shortcuts loaded\ncompletion loaded\n' > "$tmp/expected"
    diff -u "$tmp/expected" "$tmp/log"

    cat > "$tmp/bin/awk" <<'EOF'
#!/bin/sh
[ "${MISE_NOT_FOUND_AUTO_INSTALL:-}" = false ]
EOF
    chmod +x "$tmp/bin/awk"
    : > "$tmp/log"
    env -i HOME="$tmp/home" PATH="$tmp/bin" TERM=dumb _dotfiles_generation_dir="$generation" \
        TEST_PLATFORM=Darwin TEST_LOG="$tmp/log" FRAGMENT="$fragment" \
        /opt/homebrew/bin/bash --noprofile --norc -ic '. "$FRAGMENT"' 2>/dev/null
    printf 'fzf shortcuts loaded\ncompletion loaded\nfzf-tab loaded\n' > "$tmp/expected"
    diff -u "$tmp/expected" "$tmp/log"
    rm "$tmp/bin/awk"

    rm "$tmp/bin/tac"
    : > "$tmp/log"
    env -i HOME="$tmp/home" PATH="$tmp/bin" TERM=dumb _dotfiles_generation_dir="$generation" \
        TEST_PLATFORM=Linux TEST_LOG="$tmp/log" FRAGMENT="$fragment" \
        /opt/homebrew/bin/bash --noprofile --norc -ic '. "$FRAGMENT"' 2>/dev/null
    printf 'fzf shortcuts loaded\ncompletion loaded\n' > "$tmp/expected"
    diff -u "$tmp/expected" "$tmp/log"
fi

rm "$tmp/bin/fzf"
: > "$tmp/log"
if [ -x /opt/homebrew/bin/bash ]; then
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=dumb _dotfiles_generation_dir="$generation" \
        TEST_PLATFORM=Linux TEST_LOG="$tmp/log" FRAGMENT="$fragment" \
        /opt/homebrew/bin/bash --noprofile --norc -ic '. "$FRAGMENT"' 2>/dev/null
    [ "$(cat "$tmp/log")" = 'completion loaded' ]

    printf '#!/bin/sh\nexit 99\n' > "$tmp/bin/mise"
    chmod +x "$tmp/bin/mise"
    ln -s mise "$tmp/bin/fzf"
    : > "$tmp/log"
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=dumb _dotfiles_generation_dir="$generation" \
        TEST_PLATFORM=Linux TEST_LOG="$tmp/log" FRAGMENT="$fragment" \
        /opt/homebrew/bin/bash --noprofile --norc -ic '. "$FRAGMENT"' 2>/dev/null
    [ "$(cat "$tmp/log")" = 'completion loaded' ]
fi

printf 'Version-aware Bash completion tests passed\n'
