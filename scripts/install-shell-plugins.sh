#!/bin/sh
set -eu

repo=$(CDPATH='' cd -P "$(dirname "$0")/.." && pwd)
config="$repo/workspaces/sheldon/plugins.toml"
state="$HOME/.local/share/dotfiles/sheldon"
generations="$state/generations"
current="$state/current"

case "$#:${1:-}" in
    0:) mode=--relock ;;
    1:--update) mode=--update ;;
    *) printf '%s\n' 'Usage: install-shell-plugins [--update]' >&2; exit 2 ;;
esac


mise_bin=$(command -v mise || :)
if [ -z "$mise_bin" ]; then
    mise_bin="$HOME/.local/bin/mise"
fi
if [ ! -x "$mise_bin" ]; then
    printf '%s\n' 'mise is required; install it before preparing shell plugins.' >&2
    exit 1
fi

export MISE_GLOBAL_CONFIG_FILE="$repo/workspaces/mise/config.toml"
sheldon=$(MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false \
    "$mise_bin" --cd "$HOME" which sheldon)
if [ ! -x "$sheldon" ]; then
    printf '%s\n' 'Sheldon is required; run mise install first.' >&2
    exit 1
fi

mkdir -p "$generations"
previous=
if [ -L "$current" ] || { [ -e "$current" ] && [ ! -f "$current" ]; }; then
    printf 'Invalid Sheldon generation pointer: %s\n' "$current" >&2
    exit 1
fi
if [ -f "$current" ]; then
    IFS= read -r previous < "$current" || exit 1
    case $previous in
        generation.*) ;;
        *) printf 'Invalid Sheldon generation: %s\n' "$previous" >&2; exit 1 ;;
    esac
    case $previous in
        *[!a-zA-Z0-9._-]*|generation.)
            printf 'Invalid Sheldon generation: %s\n' "$previous" >&2
            exit 1
            ;;
    esac
    if [ ! -d "$generations/$previous" ]; then
        printf 'Missing Sheldon generation: %s\n' "$previous" >&2
        exit 1
    fi
fi

generation=$(mktemp -d "$generations/generation.XXXXXXXX")
if [ -n "$previous" ] && [ -d "$generations/$previous/repos" ]; then
    cp -R "$generations/$previous/repos" "$generation/repos"
fi

if [ "$mode" = --update ]; then
    "$sheldon" --config-file "$config" --data-dir "$generation" lock --update
else
    "$sheldon" --config-file "$config" --data-dir "$generation" lock
fi

# Sheldon source can report partial failures on stderr while exiting successfully.
errors="$generation/source-errors"
if ! "$sheldon" --config-file "$config" --data-dir "$generation" --quiet source \
    > "$generation/zsh-plugins.zsh" 2> "$errors"; then
    cat "$errors" >&2
    exit 1
fi
if [ -s "$errors" ]; then
    cat "$errors" >&2
    exit 1
fi


# Publish only after Sheldon has completed; old and interrupted generations remain intact.
pointer=$(mktemp "$state/.current.XXXXXXXX")
printf '%s\n' "${generation##*/}" > "$pointer"
mv -f "$pointer" "$current"
