#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/bin" "$tmp/home" "$tmp/work"

cat > "$tmp/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "$TEST_PLATFORM"
EOF
for command in ls grep rsync nnn vim nvim; do
    cat > "$tmp/bin/$command" <<'EOF'
#!/bin/sh
printf '%s' "${0##*/}" >> "$TEST_LOG"
printf ' <%s>' "$@" >> "$TEST_LOG"
printf '\n' >> "$TEST_LOG"
EOF
done
chmod +x "$tmp/bin/"*
printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/xcode-select"
chmod +x "$tmp/bin/xcode-select"

cat > "$tmp/check.sh" <<'EOF'
set -eu
if [ -n "${BASH_VERSION:-}" ]; then
    shopt -s expand_aliases
fi

cd "$TEST_WORK"
unset PI_CLIPBOARD_OSC52
unset EDITOR VISUAL
_dotfiles_shell_dir=$TEST_SHELL_DIR
. "$_dotfiles_shell_dir/platform.sh"
. "$_dotfiles_shell_dir/integrations/slurm.sh"
. "$TEST_COMMON"

[ "$EDITOR" = hx ]
[ "$VISUAL" = hx ]
sh -c '[ "$PI_CLIPBOARD_OSC52" = 1 ]'
[ -n "$SQUEUE_FORMAT" ]
before=$PWD
eval 'n'
[ "$PWD" = "$before" ]

mcd 'directory with spaces'
[ "$PWD" = "$before/directory with spaces" ]
eval '..'
[ "$PWD" = "$before" ]
mcd 'directory with spaces'
if mcd '/dev/null/impossible'; then
    printf 'mcd unexpectedly succeeded\n' >&2
    exit 1
fi
[ "$PWD" = "$before/directory with spaces" ]

eval 'vim example'
eval 'vi example'
eval 'v example'
eval 'l'
eval 'll'
eval 'lla'
eval 'grep needle'
eval 'sgrep needle .'
eval 'cpv source destination'
DOTFILES_RSYNC_BACKUP_DIR="$TEST_WORK/backup directory"
eval 'cpv source destination'
eval 'rsmv source destination'
eval 'rssync source destination'
EOF

export HOME="$tmp/home" USER=testuser TEST_WORK="$tmp/work" TEST_COMMON="$repo/home/private_dot_config/private_dotfiles/shell/preferences.sh"
export TEST_SHELL_DIR="$repo/home/private_dot_config/private_dotfiles/shell"
export PATH="$tmp/bin:/usr/bin:/bin" TEST_LOG="$tmp/log"

for shell in bash zsh; do
    executable=$(command -v "$shell")
    for TEST_PLATFORM in Darwin Linux; do
        export TEST_PLATFORM
        : > "$TEST_LOG"
        if [ "$shell" = bash ]; then
            "$executable" --noprofile --norc "$tmp/check.sh" 2>/dev/null
        else
            "$executable" -f "$tmp/check.sh" 2>/dev/null
        fi

        if [ "$TEST_PLATFORM" = Darwin ]; then
            color=-G
        else
            color=--color=auto
        fi
        printf 'nnn <>\nvim <example>\nvim <example>\nnvim <-p> <example>\nls <%s> <-lh>\nls <%s> <-lh>\nls <%s> <-lah>\ngrep <--color> <needle>\ngrep <--color> <-R> <-n> <-H> <-C> <5> <--exclude-dir=.git> <--exclude-dir=.svn> <--exclude-dir=CVS> <needle> <.>\nrsync <-poghb> <--backup-dir=/home/testuser/rsync> <--info=progress2> <--> <source> <destination>\nrsync <-poghb> <--backup-dir=%s/backup directory> <--info=progress2> <--> <source> <destination>\nrsync <-avz> <--info=progress2> <-h> <--remove-source-files> <source> <destination>\nrsync <-avzu> <--delete> <--info=progress2> <-h> <source> <destination>\n' "$color" "$color" "$color" "$tmp/work" > "$tmp/expected"
        diff -u "$tmp/expected" "$TEST_LOG"
    done
done

printf 'Common shell tests passed\n'
