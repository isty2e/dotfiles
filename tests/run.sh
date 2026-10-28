#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
cd "$repo"

python=${PYTHON:-python}
export MISE_AUTO_INSTALL=false MISE_NOT_FOUND_AUTO_INSTALL=false MISE_OFFLINE=true

pixi_usable() {
    version=$("$1" --version 2>/dev/null) || return 1
    "$python" -c 'import re, sys; m = re.match(r"pixi (\d+)\.(\d+)", sys.argv[1]); sys.exit(not m or tuple(map(int, m.groups())) < (0, 81))' "$version"
}

find_tool() (
    IFS=:
    set -f
    for directory in $PATH; do
        candidate="${directory:-.}/$1"
        if [ -f "$candidate" ] && [ -x "$candidate" ] &&
            { [ -z "${2:-}" ] || [ ! "$candidate" -ef "$2" ]; }; then
            if [ "$1" = pixi ] && ! pixi_usable "$candidate"; then
                continue
            fi
            "$python" -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$candidate"
            return
        fi
    done
    return 1
)

if [ -z "${MISE+x}" ]; then
    MISE=$(find_tool mise) || MISE=
    export MISE
fi

if [ -z "${PIXI+x}" ]; then
    PIXI=$(find_tool pixi "${MISE:-}") || PIXI=
    if [ -z "$PIXI" ] && [ -n "${MISE:-}" ]; then
        PIXI=$("$MISE" which pixi 2>/dev/null) || PIXI=
    fi
    if [ -n "$PIXI" ]; then
        if ! pixi_usable "$PIXI"; then
            printf 'Skipping native Pixi check: Pixi 0.81 or newer is unavailable\n'
            PIXI=
        fi
    fi
    export PIXI
fi

for directory in bootstrap capture chezmoi keymaps mise pixi; do
    printf '\n== Python tests: %s ==\n' "$directory"
    "$python" -m unittest discover -s "tests/$directory" -v
done

printf '\n== Vim recovery tests (offline) ==\n'
"$python" tests/vim/test_recovery.py VimRecoveryTests -v

for test in tests/shell/test_*.sh tests/slurm/test_*.sh; do
    printf '\n== %s ==\n' "$test"
    sh "$test"
done

printf '\n== Neovim setup tests ==\n'
if sh tests/nvim/run-setup.sh; then
    :
else
    status=$?
    [ "$status" -eq 77 ] || exit "$status"
fi

printf '\nThe network-backed Vim manager test and plugin-loaded editor tests are separate.\n'
printf 'Native mise and Pixi checks use detected tools or the MISE and PIXI overrides.\n'
