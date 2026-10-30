#!/bin/sh
# The snippets are expanded by the child shells.
# shellcheck disable=SC2016
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
home="$tmp/home"
fragments="$home/.config/shell"
mkdir -p "$fragments" "$tmp/bin" "$tmp/zdotdir"

for name in bash/handoff.sh device.sh platforms/init.sh generation.sh integrations/homebrew.sh \
    preferences.sh integrations/slurm.sh integrations/environment.sh \
    bash/history.sh bash/completion.sh zsh/plugins.zsh integrations/prompt.sh; do
    mkdir -p "$(dirname "$fragments/$name")"
    printf 'printf "%%s\\n" "%s" >> "$TEST_LOG"\n' "$name" > "$fragments/$name"
done
cp "$repo/home/dot_zshrc" "$tmp/zdotdir/.zshrc"

env -i HOME="$home" PATH=/usr/bin:/bin TERM=xterm TEST_LOG="$tmp/log" \
    /bin/bash --noprofile --rcfile "$repo/home/dot_bashrc" -ic ':' 2>/dev/null
printf '%s\n' bash/handoff.sh platforms/init.sh device.sh generation.sh integrations/homebrew.sh \
    preferences.sh integrations/slurm.sh integrations/environment.sh \
    bash/history.sh bash/completion.sh integrations/prompt.sh > "$tmp/expected"
diff -u "$tmp/expected" "$tmp/log"

: > "$tmp/log"
env -i HOME="$home" ZDOTDIR="$tmp/zdotdir" PATH=/usr/bin:/bin TERM=xterm TEST_LOG="$tmp/log" \
    /bin/zsh -ic '[[ $DOTFILES_ZSH_ACTIVE == 1 && :$PATH: == *:"$HOME/.local/bin":* ]]' 2>/dev/null
printf '%s\n' platforms/init.sh device.sh generation.sh integrations/homebrew.sh preferences.sh \
    integrations/slurm.sh integrations/environment.sh zsh/plugins.zsh integrations/prompt.sh > "$tmp/expected"
diff -u "$tmp/expected" "$tmp/log"

: > "$tmp/log"
env -i HOME="$home" PATH=/usr/bin:/bin TEST_LOG="$tmp/log" RC="$repo/home/dot_bashrc" \
    /bin/bash --noprofile --norc -c '. "$RC"' 2>/dev/null
env -i HOME="$home" PATH=/usr/bin:/bin TEST_LOG="$tmp/log" RC="$repo/home/dot_zshrc" \
    /bin/zsh -fc 'source "$RC"' 2>/dev/null
[ ! -s "$tmp/log" ]

# Exercise the actual handoff without starting a real Zsh or touching a login account.
cp "$repo/home/private_dot_config/private_shell/bash/handoff.sh" "$fragments/bash/handoff.sh"
cat > "$tmp/bin/uname" <<'EOF'
#!/bin/sh
printf 'Linux\n'
EOF
cat > "$tmp/bin/zsh" <<'EOF'
#!/bin/sh
printf 'handoff\n' >> "$TEST_LOG"
EOF
chmod +x "$tmp/bin/"*
: > "$tmp/log"
env -i HOME="$home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm TEST_LOG="$tmp/log" \
    SSH_CONNECTION='test' /bin/bash --noprofile --rcfile "$repo/home/dot_bashrc" -ic ':' 2>/dev/null
[ "$(cat "$tmp/log")" = handoff ]

for guard in DOTFILES_KEEP_BASH DOTFILES_ZSH_ACTIVE; do
    : > "$tmp/log"
    env -i HOME="$home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm TEST_LOG="$tmp/log" \
        SSH_CONNECTION='test' "$guard=1" /bin/bash --noprofile --rcfile "$repo/home/dot_bashrc" -ic ':' 2>/dev/null
    printf '%s\n' platforms/init.sh device.sh generation.sh integrations/homebrew.sh preferences.sh \
        integrations/slurm.sh integrations/environment.sh bash/history.sh bash/completion.sh integrations/prompt.sh > "$tmp/expected"
    diff -u "$tmp/expected" "$tmp/log"
done

# Load the actual fragments together with isolated, non-installing tool doubles.
cp -R "$repo/home/private_dot_config/private_shell/." "$fragments/"
mkdir -p "$tmp/repository/workspaces/pixi-base/.pixi/envs/default"
printf '[workspace]\nname = "base"\n' > "$tmp/repository/workspaces/pixi-base/pixi.toml"
printf "_dotfiles_repository_manifest='%s'\n" "$tmp/repository/workspaces/pixi-base/pixi.toml" \
    > "$fragments/workspaces.sh"
cat > "$tmp/bin/brew" <<'EOF'
#!/bin/sh
[ "$1" = shellenv ] || exit 1
printf 'export HOMEBREW_PREFIX=/test/brew\n'
EOF
cat > "$tmp/bin/mise" <<'EOF'
#!/bin/sh
[ "$MISE_NOT_FOUND_AUTO_INSTALL" = false ] || exit 1
[ "$MISE_AUTO_INSTALL" = false ] || exit 1
case $1 in
    activate) printf 'export TEST_MISE_ACTIVE=1\n' ;;
    which) printf '%s/pixi\n' "${0%/*}" ;;
    *) exit 1 ;;
esac
EOF
cat > "$tmp/bin/pixi" <<'EOF'
#!/bin/sh
[ "$1" = shell-hook ] && [ "$2" = --as-is ] || exit 1
printf 'export TEST_PIXI_ACTIVE=1\n'
EOF
cat > "$tmp/bin/fzf" <<'EOF'
#!/bin/sh
printf ':\n'
EOF
cat > "$tmp/bin/starship" <<'EOF'
#!/bin/sh
[ "$1" = init ] || exit 1
printf 'PS1=integration_prompt\n'
EOF
chmod +x "$tmp/bin/"*

env -i HOME="$home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm DOTFILES_KEEP_BASH=1 \
    /bin/bash --noprofile --rcfile "$repo/home/dot_bashrc" -ic '
        [ "$TEST_MISE_ACTIVE" = 1 ] && [ "$TEST_PIXI_ACTIVE" = 1 ] &&
        [ "$EDITOR" = hx ] && [ "$PS1" = integration_prompt ]
    ' 2>/dev/null
env -i HOME="$home" ZDOTDIR="$tmp/zdotdir" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm \
    /bin/zsh -ic '
        [[ $TEST_MISE_ACTIVE == 1 && $TEST_PIXI_ACTIVE == 1 &&
            $EDITOR == hx && $PS1 == integration_prompt && $DOTFILES_ZSH_ACTIVE == 1 ]]
    ' 2>/dev/null

# A device's choices override platform defaults before tool activation.
mkdir -p "$home/.config/shell/device"
cat > "$tmp/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "$TEST_PLATFORM"
EOF
cat > "$tmp/bin/xcode-select" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$tmp/bin/xcrun" <<'EOF'
#!/bin/sh
printf '/platform/sdk\n'
EOF
cat > "$tmp/bin/device-brew" <<'EOF'
#!/bin/sh
printf 'export HOMEBREW_PREFIX=/device/brew\n'
EOF
chmod +x "$tmp/bin/"*
# The same native defaults apply on both OSes without a device file.
for platform in Linux Darwin; do
    env -i HOME="$home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm DOTFILES_KEEP_BASH=1 \
        TEST_PLATFORM="$platform" /bin/bash --noprofile --rcfile "$repo/home/dot_bashrc" -ic '
            [[ $HISTCONTROL == ignoreboth && $HISTSIZE == 1000 && $HISTFILESIZE == 2000 &&
               $DOTFILES_BASH_HISTORY_SYNC == 0 ]]
        ' 2>/dev/null
    env -i HOME="$home" ZDOTDIR="$tmp/zdotdir" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm \
        TEST_PLATFORM="$platform" /bin/zsh -ic '
            [[ $HISTSIZE == 4096 && $SAVEHIST == 4096 && -o sharehistory ]]
        ' 2>/dev/null
done
cat > "$home/.config/shell/device/local.sh" <<'EOF'
printf 'loaded\n' >> "$TEST_DEVICE_LOG"
export EDITOR=device-editor
export LANG=C LC_ALL=C CPATH=/device/include
export PI_CLIPBOARD_OSC52=0 SQUEUE_FORMAT=device-queue
BREW_LOCATION="$HOME/../bin/device-brew"
HISTSIZE=8192
HISTFILESIZE=16384
SAVEHIST=6144
HISTFILE="$HOME/device history"
HISTCONTROL=ignoredups
DOTFILES_BASH_HISTORY_SYNC=0
if [ -n "${ZSH_VERSION:-}" ]; then unsetopt share_history; fi
EOF
for platform in Linux Darwin; do
    for shell in bash zsh; do
        : > "$tmp/device-log"
        if [ "$shell" = bash ]; then
            env -i HOME="$home" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm DOTFILES_KEEP_BASH=1 \
                TEST_PLATFORM="$platform" TEST_DEVICE_LOG="$tmp/device-log" \
                /bin/bash --noprofile --rcfile "$repo/home/dot_bashrc" -ic '
                    [ "$EDITOR" = device-editor ] && [ "$VISUAL" = device-editor ] &&
                    [ "$CPATH" = /device/include ] && [ "$LANG" = C ] &&
                    [ "$PI_CLIPBOARD_OSC52" = 0 ] && [ "$SQUEUE_FORMAT" = device-queue ] &&
                    [ "$HOMEBREW_PREFIX" = /device/brew ] &&
                    [ "$HISTSIZE" = 8192 ] && [ "$HISTFILESIZE" = 16384 ] &&
                    [ "$HISTFILE" = "$HOME/device history" ] && [ "$HISTCONTROL" = ignoredups ] &&
                    ! declare -F _dotfiles_history_sync >/dev/null
                ' 2>/dev/null
        else
            env -i HOME="$home" ZDOTDIR="$tmp/zdotdir" PATH="$tmp/bin:/usr/bin:/bin" TERM=xterm \
                TEST_PLATFORM="$platform" TEST_DEVICE_LOG="$tmp/device-log" \
                /bin/zsh -ic '
                    [[ $EDITOR == device-editor && $VISUAL == device-editor &&
                       $CPATH == /device/include && $LANG == C &&
                       $PI_CLIPBOARD_OSC52 == 0 && $SQUEUE_FORMAT == device-queue &&
                       $HOMEBREW_PREFIX == /device/brew && $HISTSIZE == 8192 &&
                       $SAVEHIST == 6144 && $HISTFILE == "$HOME/device history" && ! -o sharehistory ]]
                ' 2>/dev/null
        fi
        [ "$(cat "$tmp/device-log")" = loaded ]
    done
done

printf 'Interactive shell entrypoint tests passed\n'
