#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
generation="$tmp/home/generation"
plugins="$generation/repos/github.com"
mkdir -p "$tmp/bin" "$tmp/home" "$plugins/zsh-users/zsh-completions/src"

cat > "$tmp/bin/fzf" <<'EOF'
#!/bin/sh
[ "$1" = --zsh ] || exit 1
if [ "${TEST_FAIL_FZF:-0}" = 1 ]; then exit 1; fi
if [ "${TEST_FAIL_FZF_EVAL:-0}" = 1 ]; then printf 'false\n'; exit; fi
printf '%s\n' 'print -r -- fzf-init >> "$TEST_LOG"'
printf '%s\n' 'fzf_initial_tab() { :; }; zle -N fzf_initial_tab; bindkey "^I" fzf_initial_tab'
EOF
chmod +x "$tmp/bin/fzf"

write_plugin() {
    mkdir -p "$plugins/${1%/*}"
    # TEST_LOG is expanded by the sourced Zsh plugin.
    # shellcheck disable=SC2016
    printf 'print -r -- %s >> "$TEST_LOG"\n' "$2" > "$plugins/$1"
}

write_plugin 'Aloxaf/fzf-tab/fzf-tab.plugin.zsh' fzf-tab
cat >> "$plugins/Aloxaf/fzf-tab/fzf-tab.plugin.zsh" <<'EOF'
(( $+functions[compdef] )) || return 1
fzf_tab_select() { :; }
zle -N fzf_tab_select
bindkey '^I' fzf_tab_select
EOF
write_plugin 'chrissicool/zsh-256color/zsh-256color.plugin.zsh' color
write_plugin 'Tarrasch/zsh-command-not-found/command-not-found.plugin.zsh' command-not-found
write_plugin 'ohmyzsh/ohmyzsh/plugins/extract/extract.plugin.zsh' extract
write_plugin 'ohmyzsh/ohmyzsh/plugins/rsync/rsync.plugin.zsh' rsync
write_plugin 'ohmyzsh/ohmyzsh/plugins/dirhistory/dirhistory.plugin.zsh' dirhistory
write_plugin 'zsh-users/zsh-autosuggestions/zsh-autosuggestions.zsh' autosuggestions
write_plugin 'zsh-users/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' highlighting
write_plugin 'zsh-users/zsh-history-substring-search/zsh-history-substring-search.zsh' history
cat >> "$plugins/zsh-users/zsh-history-substring-search/zsh-history-substring-search.zsh" <<'EOF'
history-substring-search-up() { :; }
history-substring-search-down() { :; }
zle -N history-substring-search-up
zle -N history-substring-search-down
EOF

cat > "$generation/zsh-plugins.zsh" <<'EOF'
for plugin in \
    chrissicool/zsh-256color/zsh-256color.plugin.zsh \
    Tarrasch/zsh-command-not-found/command-not-found.plugin.zsh \
    ohmyzsh/ohmyzsh/plugins/extract/extract.plugin.zsh \
    ohmyzsh/ohmyzsh/plugins/rsync/rsync.plugin.zsh \
    ohmyzsh/ohmyzsh/plugins/dirhistory/dirhistory.plugin.zsh \
    zsh-users/zsh-autosuggestions/zsh-autosuggestions.zsh \
    zsh-users/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    zsh-users/zsh-history-substring-search/zsh-history-substring-search.zsh; do
    source "$_dotfiles_generation_dir/repos/github.com/$plugin"
done
EOF

fragment="$repo/home/private_dot_config/private_dotfiles/shell/zsh/plugins.zsh"
export HOME="$tmp/home" PATH="$tmp/bin:/usr/bin:/bin" TEST_LOG="$tmp/log" FRAGMENT="$fragment" TERM=xterm
export _dotfiles_generation_dir="$generation"

# shellcheck disable=SC2016
completion_fpath=$(env -i HOME="$HOME" PATH=/usr/bin:/bin zsh -fc '
    for directory in $fpath; do
        if [[ -r $directory/compinit ]]; then
            print -r -- "$directory"
            exit 0
        fi
    done
    exit 1
')
export FPATH="$completion_fpath"

: > "$TEST_LOG"
zsh -fic '. "$FRAGMENT"; bindkey "^I"; bindkey "^[[A"; bindkey "^[[B"; bindkey "$terminfo[kcuu1]"; bindkey "$terminfo[kcud1]"' > "$tmp/bindings"
printf '%s\n' fzf-init fzf-tab color command-not-found extract rsync dirhistory autosuggestions highlighting history > "$tmp/expected"
diff -u "$tmp/expected" "$TEST_LOG"
grep -q 'fzf_tab_select' "$tmp/bindings"
grep -q 'history-substring-search-up' "$tmp/bindings"
grep -q 'history-substring-search-down' "$tmp/bindings"
[ "$(grep -c 'history-substring-search-up' "$tmp/bindings")" -eq 2 ]
[ "$(grep -c 'history-substring-search-down' "$tmp/bindings")" -eq 2 ]

: > "$TEST_LOG"
zsh -fc '. "$FRAGMENT"'
[ ! -s "$TEST_LOG" ]

unset _dotfiles_generation_dir
: > "$TEST_LOG"
zsh -fic '. "$FRAGMENT"; (( $+functions[compdef] ))'
[ "$(cat "$TEST_LOG")" = fzf-init ]
export _dotfiles_generation_dir="$generation"

for failure in TEST_FAIL_FZF TEST_FAIL_FZF_EVAL; do
    : > "$TEST_LOG"
    env "$failure=1" zsh -fic '. "$FRAGMENT"'
    printf '%s\n' color command-not-found extract rsync dirhistory autosuggestions highlighting history > "$tmp/expected"
    diff -u "$tmp/expected" "$TEST_LOG"
done

rm "$tmp/bin/fzf"
: > "$TEST_LOG"
zsh -fic '. "$FRAGMENT"'
if grep -q '^fzf-tab$' "$TEST_LOG"; then
    printf 'fzf-tab loaded without fzf\n' >&2
    exit 1
fi

printf 'Zsh plugin initialization tests passed\n'
