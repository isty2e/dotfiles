#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/bin" "$tmp/home"

cat > "$tmp/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "$TEST_PLATFORM"
EOF
cat > "$tmp/bin/zsh" <<'EOF'
#!/bin/sh
[ "${DOTFILES_ZSH_ACTIVE:-}" = 1 ] || exit 1
[ -z "${TEST_EXPECT_SHELL:-}" ] || [ "$SHELL" = "$TEST_EXPECT_SHELL" ] || exit 1
printf 'zsh handoff\n'
EOF
chmod +x "$tmp/bin/"*

fragment="$repo/home/private_dot_config/private_shell/bash/handoff.sh"
run_case() {
    shell=$1
    flags=$2
    shift 2
    # The child shell must expand FRAGMENT, not the test shell.
    # shellcheck disable=SC2016
    env -i HOME="$tmp/home" PATH="$tmp/bin" FRAGMENT="$fragment" TERM=dumb \
        "$@" "$shell" --noprofile --norc "$flags" \
        '. "$FRAGMENT"; printf "bash remains\n"' 2>/dev/null
}

for shell in /bin/bash /opt/homebrew/bin/bash; do
    [ -x "$shell" ] || continue

    output=$(run_case "$shell" -ic TEST_PLATFORM=Linux SSH_CONNECTION=remote)
    [ "$output" = 'zsh handoff' ]

    output=$(run_case "$shell" -ic TEST_PLATFORM=Linux SSH_CONNECTION=remote \
        SHELL=/original/bash TEST_EXPECT_SHELL="$tmp/bin/zsh")
    [ "$output" = 'zsh handoff' ]

    output=$(run_case "$shell" -c TEST_PLATFORM=Linux SSH_CONNECTION=remote)
    [ "$output" = 'bash remains' ]

    output=$(run_case "$shell" -ic TEST_PLATFORM=Linux SSH_CONNECTION=remote DOTFILES_KEEP_BASH=1)
    [ "$output" = 'bash remains' ]

    output=$(run_case "$shell" -ic TEST_PLATFORM=Linux SSH_CONNECTION=remote DOTFILES_ZSH_ACTIVE=1)
    [ "$output" = 'bash remains' ]

    output=$(run_case "$shell" -ic TEST_PLATFORM=Linux SSH_CONNECTION=)
    [ "$output" = 'bash remains' ]

    output=$(run_case "$shell" -ic TEST_PLATFORM=Darwin SSH_CONNECTION=remote)
    [ "$output" = 'bash remains' ]

    mv "$tmp/bin/zsh" "$tmp/zsh-disabled"
    output=$(run_case "$shell" -ic TEST_PLATFORM=Linux SSH_CONNECTION=remote)
    [ "$output" = 'bash remains' ]
    mv "$tmp/zsh-disabled" "$tmp/bin/zsh"
done

# A missing mise-managed Zsh must not be installed by the handoff.
mv "$tmp/bin/zsh" "$tmp/real-zsh"
cat > "$tmp/bin/mise" <<'EOF'
#!/bin/sh
[ "$1" = which ] && [ "$2" = zsh ] || exit 9
[ "$MISE_AUTO_INSTALL" = false ] && [ "$MISE_NOT_FOUND_AUTO_INSTALL" = false ] || exit 9
exit 1
EOF
chmod +x "$tmp/bin/mise"
ln -s mise "$tmp/bin/zsh"
output=$(run_case /bin/bash -ic TEST_PLATFORM=Linux SSH_CONNECTION=remote)
[ "$output" = 'bash remains' ]

# An already installed mise-managed Zsh can still be used.
cat > "$tmp/bin/mise" <<'EOF'
#!/bin/sh
[ "$1" = which ] && [ "$2" = zsh ] || exit 9
[ "$MISE_AUTO_INSTALL" = false ] && [ "$MISE_NOT_FOUND_AUTO_INSTALL" = false ] || exit 9
printf '%s\n' "$TEST_ZSH"
EOF
output=$(run_case /bin/bash -ic TEST_PLATFORM=Linux SSH_CONNECTION=remote TEST_ZSH="$tmp/real-zsh")
[ "$output" = 'zsh handoff' ]

# An executable with a missing interpreter cannot complete the handoff.
rm "$tmp/bin/zsh"
printf '#!/nonexistent/dotfiles-interpreter\n' > "$tmp/bin/zsh"
chmod +x "$tmp/bin/zsh"
# Child Bash expands these snippets, not the test shell.
# shellcheck disable=SC2016
output=$(env -i HOME="$tmp/home" PATH="$tmp/bin" FRAGMENT="$fragment" TERM=dumb \
    TEST_PLATFORM=Linux SSH_CONNECTION=remote SHELL=/original/bash /bin/bash --noprofile --norc -ic \
    '. "$FRAGMENT"; if shopt -q execfail; then state=on; else state=off; fi; printf "marker=%s execfail=%s shell=%s\n" "${DOTFILES_ZSH_ACTIVE-unset}" "$state" "$SHELL"' 2>/dev/null)
[ "$output" = 'marker=unset execfail=off shell=/original/bash' ]
# shellcheck disable=SC2016
output=$(env -i HOME="$tmp/home" PATH="$tmp/bin" FRAGMENT="$fragment" TERM=dumb \
    TEST_PLATFORM=Linux SSH_CONNECTION=remote DOTFILES_ZSH_ACTIVE=before /bin/bash --noprofile --norc -ic \
    'shopt -s execfail; . "$FRAGMENT"; if shopt -q execfail; then state=on; else state=off; fi; printf "marker=%s execfail=%s\n" "$DOTFILES_ZSH_ACTIVE" "$state"' 2>/dev/null)
[ "$output" = 'marker=before execfail=on' ]

printf 'Bash handoff tests passed\n'
