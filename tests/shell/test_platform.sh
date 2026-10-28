#!/bin/sh
# The quoted code is expanded by the child shells.
# shellcheck disable=SC2016
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/home" "$tmp/bin"
fragment="$repo/home/private_dot_config/dotfiles/shell/platform.sh"

cat > "$tmp/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "$TEST_PLATFORM"
EOF
cat > "$tmp/bin/brew" <<'EOF'
#!/bin/sh
[ "$1" = shellenv ] || exit 1
[ "$MISE_NOT_FOUND_AUTO_INSTALL" = false ] || exit 2
[ "$MISE_AUTO_INSTALL" = false ] || exit 3
printf '%s\n' 'export HOMEBREW_PREFIX=/test/brew'
EOF
cat > "$tmp/bin/xcode-select" <<'EOF'
#!/bin/sh
[ "$1" = -p ]
EOF
cat > "$tmp/bin/xcrun" <<'EOF'
#!/bin/sh
[ "$1" = --show-sdk-path ] || exit 1
printf '/test/sdk\n'
EOF
chmod +x "$tmp/bin/"*

for shell in /bin/bash /bin/zsh; do
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TEST_PLATFORM=Darwin \
        FRAGMENT="$fragment" CPATH=/existing/include "$shell" -c '
            . "$FRAGMENT"
            [ "$HOMEBREW_PREFIX" = /test/brew ] || exit 1
            [ "$CPATH" = /test/sdk/usr/include:/existing/include ] || exit 1
            . "$FRAGMENT"
            [ "$CPATH" = /test/sdk/usr/include:/existing/include ]
        '
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TEST_PLATFORM=Linux \
        FRAGMENT="$fragment" "$shell" -c '
            . "$FRAGMENT"
            [ "$HOMEBREW_PREFIX" = /test/brew ] || exit 1
            [ "$LANG" = C.UTF-8 ] && [ "$LC_ALL" = C.UTF-8 ]
        '
done

# A missing developer-tool selection must not invoke xcrun during startup.
cat > "$tmp/bin/xcode-select" <<'EOF'
#!/bin/sh
exit 1
EOF
cat > "$tmp/bin/xcrun" <<'EOF'
#!/bin/sh
printf 'invoked\n' > "$TEST_LOG"
exit 1
EOF
for shell in /bin/bash /bin/zsh; do
    rm -f "$tmp/log"
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TEST_PLATFORM=Darwin \
        TEST_LOG="$tmp/log" FRAGMENT="$fragment" "$shell" -c '. "$FRAGMENT"'
    [ ! -e "$tmp/log" ]
done

# An unresolved mise shim must not be invoked as Homebrew at startup.
rm "$tmp/bin/brew"
cat > "$tmp/bin/mise" <<'EOF'
#!/bin/sh
printf 'invoked\n' > "$TEST_LOG"
exit 1
EOF
chmod +x "$tmp/bin/mise"
ln -s mise "$tmp/bin/brew"
for shell in /bin/bash /bin/zsh; do
    rm -f "$tmp/log"
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TEST_PLATFORM=Linux \
        TEST_LOG="$tmp/log" FRAGMENT="$fragment" "$shell" -c '. "$FRAGMENT"'
    [ ! -e "$tmp/log" ]
done

printf 'Platform shell configuration tests passed\n'
