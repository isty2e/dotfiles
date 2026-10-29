#!/bin/sh
set -eu

case ${1-} in
    -h|--help)
        printf '%s\n' 'Usage: sh bootstrap.sh' \
            'Prepare chezmoi and mise, bind this checkout, and apply its configuration.' \
            'Missing bootstrap tools use their official installers in ~/.local/bin.' \
            'Bootstrap explicitly installs mise tools and prepares shell plugins after apply.' \
            'Existing or changed targets stop apply for manual review; partial changes may remain.' \
            'Pixi environments, editor plugins, logins and shell changes remain manual.'
        exit 0
        ;;
esac
if [ "$#" -ne 0 ]; then
    printf '%s\n' 'Usage: sh bootstrap.sh' >&2
    exit 1
fi

: "${HOME:?HOME must be set}"
repo=$(CDPATH='' cd -P "$(dirname "$0")" && pwd)
export PATH="$HOME/.local/bin:${PATH:-/usr/bin:/bin}"

if ! command -v chezmoi >/dev/null 2>&1 || ! command -v mise >/dev/null 2>&1; then
    command -v curl >/dev/null 2>&1 || {
        printf '%s\n' 'curl is required to download the missing bootstrap tools.' >&2
        exit 1
    }
    temporary=$(mktemp -d)
    trap 'rm -rf "$temporary"' 0
    trap 'exit 1' HUP INT TERM
    mkdir -p "$HOME/.local/bin"

    if ! command -v chezmoi >/dev/null 2>&1; then
        printf '%s\n' 'Installing chezmoi in ~/.local/bin using get.chezmoi.io'
        curl -fsSL --proto '=https' --proto-redir '=https' \
            https://get.chezmoi.io -o "$temporary/chezmoi.sh"
        sh "$temporary/chezmoi.sh" -b "$HOME/.local/bin"
    fi
    if ! command -v mise >/dev/null 2>&1; then
        printf '%s\n' 'Installing mise in ~/.local/bin using mise.run'
        curl -fsSL --proto '=https' --proto-redir '=https' \
            https://mise.run -o "$temporary/mise.sh"
        MISE_INSTALL_PATH="$HOME/.local/bin/mise" sh "$temporary/mise.sh"
    fi
    hash -r
fi

chezmoi_bin=$(command -v chezmoi)
"$chezmoi_bin" --version >/dev/null
mise --version >/dev/null
config_file=$("$chezmoi_bin" execute-template '{{ .chezmoi.configFile }}')

set -- --less-interactive --error-on-conflict
if [ -e "$config_file" ] || [ -L "$config_file" ]; then
    active_source=$("$chezmoi_bin" source-path)
    expected_source=$("$chezmoi_bin" --source "$repo" source-path)
    if [ ! -d "$active_source" ] || \
        [ "$(CDPATH='' cd -P "$active_source" && pwd)" != "$expected_source" ]; then
        printf '%s\n' \
            'chezmoi is configured for another source; no configuration was applied.' \
            "Review $config_file and set sourceDir to $repo before retrying." >&2
        exit 1
    fi
    set -- apply "$@"
else
    if [ ! -e "$HOME/.config" ] && [ ! -L "$HOME/.config" ]; then
        mkdir -m 700 "$HOME/.config"
    fi
    set -- --source "$repo" init --apply "$@"
fi

if "$chezmoi_bin" "$@"; then
    :
else
    rc=$?
    printf '%s\n' \
        "chezmoi apply did not complete (exit $rc). Some configuration may already have changed." \
        'No rollback or automatic backup was attempted.' \
        'Back up affected files and link targets privately before resolving differences.' \
        "If tools were just installed, add $HOME/.local/bin to PATH in this shell." \
        'Review: chezmoi diff' \
        'Choose changes manually: chezmoi apply --less-interactive' \
        'After resolving differences, rerun bootstrap to finish any pending setup.' >&2
    exit "$rc"
fi

export MISE_GLOBAL_CONFIG_FILE="$repo/workspaces/mise/config.toml"
if mise --cd "$HOME" install && sh "$repo/scripts/install-shell-plugins.sh"; then
    :
else
    rc=$?
    printf '%s\n' 'Configuration was placed, but explicit tool setup did not complete.' \
        'Installed tools and previous plugin generations were not rolled back.' \
        'Resolve the native error and rerun bootstrap to retry.' >&2
    exit "$rc"
fi

printf '%s\n' 'chezmoi apply completed. See setup.md for shell activation.' \
    'Install the Pixi base environment and editor plugins separately; see setup.md.'
