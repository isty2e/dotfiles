#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
export CHEZMOI_DEST_DIR="$tmp/destination"
export HOME="$CHEZMOI_DEST_DIR"
export TEST_LOG="$tmp/sheldon.log"
export PATH="$tmp/bin:/usr/bin:/bin"
mkdir -p "$tmp/bin" "$CHEZMOI_DEST_DIR/.config/dotfiles/shell"

cat > "$tmp/bin/mise" <<'EOF'
#!/bin/sh
[ "$3" = which ] && [ "$4" = sheldon ]
printf '%s\n' "$TEST_SHELDON"
EOF
cat > "$tmp/bin/sheldon" <<'EOF'
#!/bin/sh
set -eu
if [ "$5" = lock ]; then
    printf '%s\n' "${6:-normal}" >> "$TEST_LOG"
    mkdir -p "$4/repos/github.com/example/first"
    printf '%s\n' attempt > "$4/repos/github.com/example/first/marker"
    [ "${FAIL_PREPARATION:-no}" != yes ]
    exit 0
fi
[ "$5" = --quiet ] && [ "$6" = source ]
if [ "${FAIL_SOURCE:-no}" = yes ]; then
    printf '%s\n' 'partial source failure' >&2
fi
printf '%s\n' 'prepared loader'

EOF
chmod +x "$tmp/bin/mise" "$tmp/bin/sheldon"
export TEST_SHELDON="$tmp/bin/sheldon"

manifest="$CHEZMOI_DEST_DIR/.config/dotfiles/shell/plugins.toml"
printf '%s\n' '[plugins.first]' 'github = "example/first"' > "$manifest"
legacy="$CHEZMOI_DEST_DIR/.local/share/dotfiles/plugins/first"
mkdir -p "$legacy"
printf '%s\n' 'existing checkout' > "$legacy/marker"

prepare() {
    sh "$repo/scripts/install-shell-plugins.sh" "$@"
}

state="$CHEZMOI_DEST_DIR/.local/share/dotfiles/sheldon"
prepare
first=$(cat "$state/current")
[ -r "$state/generations/$first/zsh-plugins.zsh" ]
[ "$(cat "$legacy/marker")" = 'existing checkout' ]
marker="$state/generations/$first/repos/github.com/example/first/marker"
printf '%s\n' 'preserve this checkout' > "$marker"

FAIL_PREPARATION=yes; export FAIL_PREPARATION
if prepare > /dev/null 2>&1; then
    printf 'Failed preparation unexpectedly succeeded\n' >&2
    exit 1
fi
[ "$(cat "$state/current")" = "$first" ]
[ "$(cat "$marker")" = 'preserve this checkout' ]
[ "$(cat "$legacy/marker")" = 'existing checkout' ]

unset FAIL_PREPARATION

FAIL_SOURCE=yes; export FAIL_SOURCE
if prepare > /dev/null 2>&1; then
    printf 'Partial source failure unexpectedly succeeded\n' >&2
    exit 1
fi
[ "$(cat "$state/current")" = "$first" ]
[ "$(cat "$marker")" = 'preserve this checkout' ]
unset FAIL_SOURCE


prepare
second=$(cat "$state/current")
[ "$second" != "$first" ]
[ -r "$state/generations/$second/zsh-plugins.zsh" ]
[ "$(cat "$marker")" = 'preserve this checkout' ]

prepare --update
third=$(cat "$state/current")
[ "$third" != "$second" ]
[ "$(tail -n 1 "$TEST_LOG")" = --update ]
[ "$(cat "$marker")" = 'preserve this checkout' ]



printf '%s\n' '../outside' > "$state/current"
if prepare > /dev/null 2>&1; then
    printf 'Invalid generation pointer unexpectedly accepted\n' >&2
    exit 1
fi
[ "$(cat "$state/current")" = '../outside' ]
[ "$(cat "$legacy/marker")" = 'existing checkout' ]

printf 'Shell plugin preparation tests passed\n'
