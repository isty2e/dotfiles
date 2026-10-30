#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/home/.config/shell/device" "$tmp/bin"

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
if [ "$1" = -f ]; then
    target=$3
else
    target=$4
fi
case $2 in %a|%Lp) gnu=%a; bsd=%Lp ;; %u) gnu=%u; bsd=%u ;; esac
/usr/bin/stat -c "$gnu" "$target" 2>/dev/null || /usr/bin/stat -f "$bsd" "$target"
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

local_file="$tmp/home/.config/shell/device/local.sh"
credential_file="$tmp/home/.config/shell/device/credentials.sh"
cat > "$local_file" <<'EOF'
TEST_LOCATION='local value with spaces'
export DK_VAULT_PATH="$TEST_VAULT_LOCATION"
EOF
printf '%s\n' "TEST_FAKE_KEY='fake value with spaces'" "mode='fake mode'" "file='fake file'" > "$credential_file"
chmod 600 "$credential_file"
export HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin"
export TEST_LOADER="$repo/config/shell/lib/device.sh"

for shell in bash zsh; do
    executable=$(command -v "$shell")
    for platform in Linux Darwin; do
        TEST_PLATFORM=$platform; export TEST_PLATFORM
        TEST_EXPECT_KEY=yes
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

TEST_EXPECT_KEY=no TEST_ALLEXPORT=no; export TEST_EXPECT_KEY TEST_ALLEXPORT
for TEST_PLATFORM in Linux Darwin; do
    export TEST_PLATFORM
    for shell in /bin/bash /bin/zsh; do
        chmod 644 "$credential_file"
        "$shell" "$tmp/check.sh" 2> "$tmp/warning"
        [ -s "$tmp/warning" ]
        chmod 600 "$credential_file"
        TEST_OTHER_OWNER=yes "$shell" "$tmp/check.sh" 2> "$tmp/warning"
        [ -s "$tmp/warning" ]
    done
done

rm "$credential_file"
bash --noprofile --norc "$tmp/check.sh"
rm "$local_file"
TEST_EXPECT_LOCAL=no; export TEST_EXPECT_LOCAL
zsh -f "$tmp/check.sh"

# Missing private files are optional on either OS.
for TEST_PLATFORM in Linux Darwin; do
    export TEST_PLATFORM
    for shell in /bin/bash /bin/zsh; do
        for TEST_ALLEXPORT in yes no; do
            export TEST_ALLEXPORT
            "$shell" "$tmp/check.sh"
        done
    done
done

printf 'Local shell configuration tests passed\n'
