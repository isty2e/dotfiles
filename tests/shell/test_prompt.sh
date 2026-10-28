#!/bin/sh
# Single-quoted snippets are evaluated by the child shell.
# shellcheck disable=SC2016
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/home" "$tmp/bin"
fragment="$repo/home/private_dot_config/private_dotfiles/shell/prompt.sh"

cat > "$tmp/bin/starship" <<'EOF'
#!/bin/sh
[ "$1" = init ] || exit 2
[ "$MISE_NOT_FOUND_AUTO_INSTALL" = false ] || exit 3
[ "$MISE_AUTO_INSTALL" = false ] || exit 4
printf '%s\n' "$2" >> "$TEST_LOG"
printf '%s\n' 'PS1=dotfiles_prompt_test'
EOF
chmod +x "$tmp/bin/starship"

for shell in bash zsh; do
    : > "$tmp/log"
    if [ "$shell" = bash ]; then
        executable=/bin/bash
        flags='--noprofile --norc'
    else
        executable=/bin/zsh
        flags=-f
    fi

    # The selected options contain no whitespace-dependent arguments.
    # shellcheck disable=SC2086
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm \
        TEST_LOG="$tmp/log" FRAGMENT="$fragment" \
        "$executable" $flags -ic '. "$FRAGMENT"; [ "$PS1" = dotfiles_prompt_test ]' 2>/dev/null
    [ "$(cat "$tmp/log")" = "$shell" ]

    : > "$tmp/log"
    # shellcheck disable=SC2086
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm \
        TEST_LOG="$tmp/log" FRAGMENT="$fragment" \
        "$executable" $flags -c '. "$FRAGMENT"' 2>/dev/null
    [ ! -s "$tmp/log" ]
done

rm "$tmp/bin/starship"
printf '#!/bin/sh\nexit 99\n' > "$tmp/bin/mise"
chmod +x "$tmp/bin/mise"
ln -s mise "$tmp/bin/starship"
for shell in /bin/bash /bin/zsh; do
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm FRAGMENT="$fragment" \
        "$shell" -ic 'PS1=original; . "$FRAGMENT"; [ "$PS1" = original ]' 2>/dev/null
done

rm "$tmp/bin/starship"
for shell in /bin/bash /bin/zsh; do
    env -i HOME="$tmp/home" PATH="$tmp/bin" TERM=xterm FRAGMENT="$fragment" \
        "$shell" -ic 'PS1=original; . "$FRAGMENT"; [ "$PS1" = original ]' 2>/dev/null
done

printf 'Prompt initialization tests passed\n'
