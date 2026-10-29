#!/bin/sh
set -eu

tmux=$(command -v tmux || :)
if [ -z "$tmux" ] || ! "$tmux" -V >/dev/null 2>&1; then
    printf 'Skipping tmux handoff test: tmux is unavailable\n'
    exit 0
fi

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap '"$tmux" -S "$tmp/socket" kill-server >/dev/null 2>&1 || :; rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/home"

cat > "$tmp/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' Linux
EOF
cat > "$tmp/bin/zsh" <<'EOF'
#!/bin/sh
exec "$TEST_TMUX" -S "$TEST_SOCKET" -f /dev/null new-session -d -s probe 'sleep 30'
EOF
chmod +x "$tmp/bin/uname" "$tmp/bin/zsh"

# The temporary tmux server receives the environment of the selected shell.
# shellcheck disable=SC2016
env -i HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" SHELL=/bin/bash \
    SSH_CONNECTION=remote TERM=xterm TEST_TMUX="$tmux" TEST_SOCKET="$tmp/socket" \
    FRAGMENT="$repo/home/private_dot_config/private_dotfiles/shell/bash-handoff.sh" \
    /bin/bash --noprofile --norc -ic '. "$FRAGMENT"' 2>/dev/null

selected=$("$tmux" -S "$tmp/socket" show-options -gv default-shell)
[ "$selected" = "$tmp/bin/zsh" ]
printf 'Tmux handoff test passed\n'
