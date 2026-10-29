#!/bin/sh
# The snippets are expanded by the child shells.
# shellcheck disable=SC2016
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
home="$tmp/home"
fragments="$home/.config/dotfiles/shell"
mkdir -p "$fragments" "$tmp/bin" "$tmp/zdotdir"

for name in bash-handoff.sh local-loader.sh platform.sh common.sh environment.sh \
    bash-history.sh bash-completion.sh zsh-options.zsh zsh-plugins.zsh prompt.sh; do
    printf 'printf "%%s\\n" "%s" >> "$TEST_LOG"\n' "$name" > "$fragments/$name"
done
cp "$repo/home/dot_zshrc" "$tmp/zdotdir/.zshrc"

env -i HOME="$home" PATH=/usr/bin:/bin TERM=xterm TEST_LOG="$tmp/log" \
    /bin/bash --noprofile --rcfile "$repo/home/dot_bashrc" -ic ':' 2>/dev/null
printf '%s\n' bash-handoff.sh local-loader.sh platform.sh common.sh environment.sh \
    bash-history.sh bash-completion.sh prompt.sh > "$tmp/expected"
diff -u "$tmp/expected" "$tmp/log"

: > "$tmp/log"
env -i HOME="$home" ZDOTDIR="$tmp/zdotdir" PATH=/usr/bin:/bin TERM=xterm TEST_LOG="$tmp/log" \
    /bin/zsh -ic '[[ $DOTFILES_ZSH_ACTIVE == 1 && :$PATH: == *:"$HOME/.local/bin":* ]]' 2>/dev/null
printf '%s\n' local-loader.sh platform.sh common.sh environment.sh zsh-options.zsh zsh-plugins.zsh prompt.sh > "$tmp/expected"
diff -u "$tmp/expected" "$tmp/log"

: > "$tmp/log"
env -i HOME="$home" PATH=/usr/bin:/bin TEST_LOG="$tmp/log" RC="$repo/home/dot_bashrc" \
    /bin/bash --noprofile --norc -c '. "$RC"' 2>/dev/null
env -i HOME="$home" PATH=/usr/bin:/bin TEST_LOG="$tmp/log" RC="$repo/home/dot_zshrc" \
    /bin/zsh -fc 'source "$RC"' 2>/dev/null
[ ! -s "$tmp/log" ]

# Exercise the actual handoff without starting a real Zsh or touching a login account.
cp "$repo/home/private_dot_config/private_dotfiles/shell/bash-handoff.sh" "$fragments/bash-handoff.sh"
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
    printf '%s\n' local-loader.sh platform.sh common.sh environment.sh bash-history.sh bash-completion.sh prompt.sh > "$tmp/expected"
    diff -u "$tmp/expected" "$tmp/log"
done

# Load the actual fragments together with isolated, non-installing tool doubles.
for path in "$repo"/home/private_dot_config/private_dotfiles/shell/*; do
    [ -f "$path" ] && cp "$path" "$fragments/"
done
mkdir -p "$home/pixi-env/base/.pixi/envs/default"
printf '[workspace]\nname = "base"\n' > "$home/pixi-env/base/pixi.toml"
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

printf 'Interactive shell entrypoint tests passed\n'
