#!/bin/sh
# Single-quoted commands are deliberately expanded by the child shell.
# shellcheck disable=SC2016
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/home/pixi-env/base/.pixi/envs/default"
touch "$tmp/home/pixi-env/base/pixi.toml"

cat > "$tmp/bin/mise" <<'EOF'
#!/bin/sh
[ "${MISE_NOT_FOUND_AUTO_INSTALL:-}" = false ] || exit 2
printf 'mise' >> "$TEST_LOG"
printf ' <%s>' "$@" >> "$TEST_LOG"
printf '\n' >> "$TEST_LOG"
case $1 in
    activate)
        if [ "${TEST_FAIL_MISE:-}" = 1 ]; then
            printf '%s\n' 'export TEST_BAD_HOOK=1'
            exit 1
        fi
        printf '%s\n' 'export TEST_MISE_LOADED=1'
        ;;
    which)
        [ -n "${TEST_MISE_PIXI:-}" ] || exit 1
        printf '%s\n' "$TEST_MISE_PIXI"
        ;;
esac
EOF
cat > "$tmp/bin/pixi" <<'EOF'
#!/bin/sh
[ "${MISE_NOT_FOUND_AUTO_INSTALL:-}" = false ] || exit 2
printf 'pixi' >> "$TEST_LOG"
printf ' <%s>' "$@" >> "$TEST_LOG"
printf '\n' >> "$TEST_LOG"
if [ "${TEST_FAIL_PIXI:-}" = 1 ]; then
    printf '%s\n' 'export TEST_BAD_HOOK=1'
    exit 1
fi
printf '%s\n' 'export TEST_PIXI_LOADED=1'
EOF
chmod +x "$tmp/bin/"*

fragment="$repo/home/private_dot_config/private_dotfiles/shell/integrations/environment.sh"
run_shell() {
    shell=$1
    shift
    case $shell in
        */bash) set -- "$@" "$shell" --noprofile --norc -ic ;;
        */zsh) set -- "$@" "$shell" -f -ic ;;
    esac
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TERM=dumb \
        TEST_LOG="$tmp/log" FRAGMENT="$fragment" "$@" \
        '. "$FRAGMENT"; printf "%s %s %s\n" "${TEST_MISE_LOADED:-0}" "${TEST_PIXI_LOADED:-0}" "${TEST_BAD_HOOK:-0}"' 2>/dev/null
}

for shell in /bin/bash /bin/zsh; do
    [ -x "$shell" ] || continue
    : > "$tmp/log"
    output=$(run_shell "$shell")
    [ "$output" = '1 1 0' ]
    grep -q '<--as-is>' "$tmp/log"
    grep -Fq "$tmp/home/pixi-env/base/pixi.toml" "$tmp/log"

    : > "$tmp/log"
    output=$(run_shell "$shell" PIXI_PROJECT_MANIFEST=/project/pixi.toml)
    [ "$output" = '1 0 0' ]
    if grep -q '^pixi' "$tmp/log"; then
        printf 'An active Pixi project was replaced\n' >&2
        exit 1
    fi

    : > "$tmp/log"
    output=$(run_shell "$shell" VIRTUAL_ENV=/project/venv)
    [ "$output" = '1 0 0' ]
    if grep -q '^pixi' "$tmp/log"; then
        printf 'An active virtualenv was replaced\n' >&2
        exit 1
    fi

    : > "$tmp/log"
    output=$(run_shell "$shell" CONDA_PREFIX=/project/conda)
    [ "$output" = '1 0 0' ]
    if grep -q '^pixi' "$tmp/log"; then
        printf 'An active Conda environment was replaced\n' >&2
        exit 1
    fi

    : > "$tmp/log"
    output=$(run_shell "$shell" TEST_FAIL_PIXI=1)
    [ "$output" = '1 0 0' ]

    : > "$tmp/log"
    output=$(run_shell "$shell" TEST_FAIL_MISE=1)
    [ "$output" = '0 1 0' ]

    : > "$tmp/log"
    output=$(run_shell "$shell" "TEST_MISE_PIXI=$tmp/bin/pixi")
    [ "$output" = '1 1 0' ]
    grep -q '<--as-is>' "$tmp/log"
done

: > "$tmp/log"
env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TEST_LOG="$tmp/log" \
    FRAGMENT="$fragment" /bin/bash --noprofile --norc -c '. "$FRAGMENT"'
[ ! -s "$tmp/log" ]

if [ -x /bin/zsh ]; then
    : > "$tmp/log"
    env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TEST_LOG="$tmp/log" \
        FRAGMENT="$fragment" /bin/zsh -fc '. "$FRAGMENT"'
    [ ! -s "$tmp/log" ]
fi

mkdir -p "$tmp/home/pixi_envs/base/.pixi/envs/default"
touch "$tmp/home/pixi_envs/base/pixi.toml"
: > "$tmp/log"
run_shell /bin/bash > /dev/null
grep -Fq "$tmp/home/pixi_envs/base/pixi.toml" "$tmp/log"

mkdir -p "$tmp/custom path/base/.pixi/envs/default"
touch "$tmp/custom path/base/pixi.toml"
: > "$tmp/log"
run_shell /bin/bash "PIXI_ENVS_HOME=$tmp/custom path" > /dev/null
grep -Fq "$tmp/custom path/base/pixi.toml" "$tmp/log"

: > "$tmp/log"
output=$(run_shell /bin/bash "DOTFILES_PIXI_BASE_MANIFEST=$tmp/missing/pixi.toml")
[ "$output" = '1 0 0' ]
if grep -q 'shell-hook' "$tmp/log"; then
    printf 'A missing environment was unexpectedly activated\n' >&2
    exit 1
fi

mkdir -p "$tmp/repository/workspaces/pixi-base/.pixi/envs/default" "$tmp/home/.config/dotfiles/shell"
touch "$tmp/repository/workspaces/pixi-base/pixi.toml"
printf "_dotfiles_repository_manifest='%s'\n" "$tmp/repository/workspaces/pixi-base/pixi.toml" \
    > "$tmp/home/.config/dotfiles/shell/workspaces.sh"
: > "$tmp/log"
run_shell /bin/bash > /dev/null
grep -Fq "$tmp/repository/workspaces/pixi-base/pixi.toml" "$tmp/log"

: > "$tmp/log"
run_shell /bin/bash "PIXI_ENVS_HOME=$tmp/custom path" > /dev/null
grep -Fq "$tmp/custom path/base/pixi.toml" "$tmp/log"

rm "$tmp/bin/pixi"
ln -s mise "$tmp/bin/pixi"
: > "$tmp/log"
output=$(run_shell /bin/bash)
[ "$output" = '1 0 0' ]
if grep -q 'shell-hook' "$tmp/log"; then
    printf 'A missing Pixi shim was executed\n' >&2
    exit 1
fi

printf 'Shell environment activation tests passed\n'
