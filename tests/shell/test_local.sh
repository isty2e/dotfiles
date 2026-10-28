#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/home/.config/dotfiles" "$tmp/bin"

cat > "$tmp/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "$TEST_PLATFORM"
EOF
cat > "$tmp/bin/stat" <<'EOF'
#!/bin/sh
if [ "$2" = %u ] && [ "${TEST_OTHER_OWNER:-}" = yes ]; then
    printf '999999\n'
    exit
fi
if /usr/bin/stat -c "$2" "$4" 2>/dev/null; then
    exit
fi
case $2 in
    %a) /usr/bin/stat -f '%Lp' "$4" ;;
    %u) /usr/bin/stat -f '%u' "$4" ;;
esac
EOF
chmod +x "$tmp/bin/"*

cat > "$tmp/check.sh" <<'EOF'
set -eu
if [ "${TEST_ALLEXPORT:-}" = yes ]; then
    set -a
fi

unset DK_VAULT_PATH
. "$TEST_LOADER"

if [ "${TEST_EXPECT_LOCAL:-yes}" = yes ]; then
    [ "${TEST_LOCATION:-}" = 'local value with spaces' ]
    sh -c '[ "$DK_VAULT_PATH" = "$TEST_VAULT_LOCATION" ]'
else
    [ -z "${TEST_LOCATION:-}" ]
    [ -z "${DK_VAULT_PATH:-}" ]
fi
if [ "${TEST_EXPECT_KEY:-}" = yes ]; then
    [ "${TEST_FAKE_KEY:-}" = 'fake value with spaces' ]
    [ "${mode:-}" = 'fake mode' ]
    [ "${file:-}" = 'fake file' ]
    env | grep -q '^TEST_FAKE_KEY=fake value with spaces$'
else
    [ -z "${TEST_FAKE_KEY:-}" ]
fi
case $- in
    *a*) [ "${TEST_ALLEXPORT:-}" = yes ] ;;
    *) [ "${TEST_ALLEXPORT:-}" != yes ] ;;
esac
EOF

local_file="$tmp/home/.config/dotfiles/local.sh"
credential_file="$tmp/home/.config/dotfiles/credentials.sh"
cat > "$local_file" <<'EOF'
TEST_LOCATION='local value with spaces'
export DK_VAULT_PATH="$TEST_VAULT_LOCATION"
EOF
printf '%s\n' "TEST_FAKE_KEY='fake value with spaces'" "mode='fake mode'" "file='fake file'" > "$credential_file"
chmod 600 "$credential_file"
export HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin"
export TEST_LOADER="$repo/home/private_dot_config/dotfiles/shell/local-loader.sh"

for shell in bash zsh; do
    executable=$(command -v "$shell")
    for platform in Linux Darwin; do
        TEST_PLATFORM=$platform; export TEST_PLATFORM
        if [ "$platform" = Linux ]; then TEST_EXPECT_KEY=yes; else TEST_EXPECT_KEY=no; fi
        export TEST_EXPECT_KEY
        for TEST_VAULT_LOCATION in "$tmp/vaults/first machine" "$tmp/storage/second-vault"; do
            export TEST_VAULT_LOCATION
            for TEST_ALLEXPORT in yes no; do
                export TEST_ALLEXPORT
                if [ "$shell" = bash ]; then
                    "$executable" --noprofile --norc "$tmp/check.sh"
                else
                    "$executable" -f "$tmp/check.sh"
                fi
            done
        done
    done
done

chmod 644 "$credential_file"
TEST_PLATFORM=Linux TEST_EXPECT_KEY=no TEST_ALLEXPORT=no; export TEST_PLATFORM TEST_EXPECT_KEY TEST_ALLEXPORT
bash --noprofile --norc "$tmp/check.sh" 2> "$tmp/warning"
[ -s "$tmp/warning" ]
zsh -f "$tmp/check.sh" 2> "$tmp/warning"
[ -s "$tmp/warning" ]

chmod 600 "$credential_file"
TEST_OTHER_OWNER=yes; export TEST_OTHER_OWNER
bash --noprofile --norc "$tmp/check.sh" 2> "$tmp/warning"
[ -s "$tmp/warning" ]
unset TEST_OTHER_OWNER

rm "$credential_file"
bash --noprofile --norc "$tmp/check.sh"
rm "$local_file"
TEST_EXPECT_LOCAL=no; export TEST_EXPECT_LOCAL
zsh -f "$tmp/check.sh"

printf 'Local shell configuration tests passed\n'
