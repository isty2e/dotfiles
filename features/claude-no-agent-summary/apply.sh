#!/bin/sh
set -eu

case "$#:${1:-}" in
    2:on|2:off) ;;
    *) printf '%s\n' 'Usage: apply.sh on|off URL' >&2; exit 2 ;;
esac

directory="$HOME/.local/share"
hook="$directory/no-agent-summary.js"
if [ -d "$hook" ]; then
    printf 'Expected a file, not a directory: %s\n' "$hook" >&2
    exit 1
fi

if [ "$1" = off ]; then
    rm -f -- "$hook"
    exit 0
fi

mkdir -p "$directory"
temporary=$(mktemp "$directory/.no-agent-summary.XXXXXXXX")
trap 'rm -f -- "$temporary"' EXIT
trap 'exit 1' HUP INT TERM

# Never publish a partial response over a working preload.
curl --fail --location --silent --show-error --output "$temporary" -- "$2"
if [ -f "$hook" ] && cmp -s "$temporary" "$hook"; then
    exit 0
fi
mv -f -- "$temporary" "$hook"
