#!/bin/sh
# The quoted snippets are expanded by the child shells.
# shellcheck disable=SC2016
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
generation="$tmp/home/generation"
plugin="$generation/repos/github.com/ohmyzsh/ohmyzsh/plugins/extract/extract.plugin.zsh"
mkdir -p "${plugin%/*}" "$tmp/work" "$tmp/bin"

cat > "$plugin" <<'EOF'
extract() {
    printf '<%s>\n' "$@" > "$TEST_LOG"
    builtin cd /
    return "${TEST_RESULT:-0}"
}
EOF
cat > "$tmp/check.sh" <<'EOF'
. "$COMMON"
cd "$TEST_WORK"
before=$PWD
extract -t 'target directory' 'archive with spaces.tar.zst'
[ "$PWD" = "$before" ] || exit 1
TEST_RESULT=7
export TEST_RESULT
if extract failed; then
    exit 1
else
    [ "$?" -eq 7 ] || exit 1
fi
EOF

env -i HOME="$tmp/home" PATH=/usr/bin:/bin TEST_LOG="$tmp/log" TEST_WORK="$tmp/work" _dotfiles_generation_dir="$generation" \
    COMMON="$repo/home/private_dot_config/private_shell/preferences.sh" \
    /bin/bash --noprofile --norc "$tmp/check.sh"
printf '<failed>\n' > "$tmp/expected"
diff -u "$tmp/expected" "$tmp/log"

# The test plugin receives each argument intact, including spaces and options.
env -i HOME="$tmp/home" PATH=/usr/bin:/bin TEST_LOG="$tmp/log" _dotfiles_generation_dir="$generation" \
    COMMON="$repo/home/private_dot_config/private_shell/preferences.sh" \
    /bin/bash --noprofile --norc -c '. "$COMMON"; extract -t "target directory" "archive with spaces.tar.zst"'
printf '<-t>\n<target directory>\n<archive with spaces.tar.zst>\n' > "$tmp/expected"
diff -u "$tmp/expected" "$tmp/log"

printf '#!/bin/sh\nprintf "Linux\\n"\n' > "$tmp/bin/uname"
chmod +x "$tmp/bin/uname"
if env -i HOME="$tmp/home" PATH="$tmp/bin" _dotfiles_generation_dir="$generation" COMMON="$repo/home/private_dot_config/private_shell/preferences.sh" \
    /bin/bash --noprofile --norc -c '. "$COMMON"; extract archive' 2>/dev/null; then
    printf 'extract unexpectedly succeeded without zsh\n' >&2
    exit 1
fi

rm "$plugin"
if env -i HOME="$tmp/home" PATH=/usr/bin:/bin _dotfiles_generation_dir="$generation" COMMON="$repo/home/private_dot_config/private_shell/preferences.sh" \
    /bin/bash --noprofile --norc -c '. "$COMMON"; extract archive' 2>/dev/null; then
    printf 'extract unexpectedly succeeded without its plugin\n' >&2
    exit 1
fi

printf 'Bash extract adapter tests passed\n'
