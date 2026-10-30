# Bootstrap prepares plugins; interactive startup only loads a ready generation.
[[ -o interactive ]] || return 0

# Homebrew completion must be prepared before compinit, on either OS.
if [[ -n ${HOMEBREW_PREFIX:-} && -n ${_dotfiles_generation_dir:-} &&
      -r $_dotfiles_generation_dir/repos/github.com/ohmyzsh/ohmyzsh/plugins/brew/brew.plugin.zsh ]]; then
    source "$_dotfiles_generation_dir/repos/github.com/ohmyzsh/ohmyzsh/plugins/brew/brew.plugin.zsh" || :
fi

# Completion definitions must be on fpath before compinit.
if [[ -n ${_dotfiles_generation_dir:-} &&
      -d $_dotfiles_generation_dir/repos/github.com/zsh-users/zsh-completions/src ]]; then
    fpath=("$_dotfiles_generation_dir/repos/github.com/zsh-users/zsh-completions/src" $fpath)
fi
autoload -Uz compinit
compinit

# Initialize fzf before fzf-tab so the final Tab binding belongs to fzf-tab.
_dotfiles_fzf=$(whence -p fzf 2>/dev/null) || _dotfiles_fzf=
_dotfiles_mise=$(whence -p mise 2>/dev/null) || _dotfiles_mise=
if [[ -n $_dotfiles_fzf && -x $_dotfiles_fzf ]] &&
    { [[ -z $_dotfiles_mise ]] || [[ ! $_dotfiles_fzf -ef $_dotfiles_mise ]]; }; then
    if _dotfiles_hook=$(MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false \
        "$_dotfiles_fzf" --zsh); then
        if eval "$_dotfiles_hook"; then
            # Loading the selector is owned by this successful initialization,
            # not by a status variable interpreted in a generated script.
            _dotfiles_fzf_tab="${_dotfiles_generation_dir:-}/repos/github.com/Aloxaf/fzf-tab/fzf-tab.plugin.zsh"
            if [[ -n ${_dotfiles_generation_dir:-} && -r $_dotfiles_fzf_tab ]]; then
                source "$_dotfiles_fzf_tab" || :
            fi
        fi
    fi
fi

if [[ -n ${_dotfiles_generation_dir:-} && -r $_dotfiles_generation_dir/zsh-plugins.zsh ]]; then
    source "$_dotfiles_generation_dir/zsh-plugins.zsh" || :
fi

# Bind history search only after its widgets have been defined.
zmodload -i zsh/terminfo 2>/dev/null || :
if (( ${+widgets[history-substring-search-up]} )); then
    bindkey '^[[A' history-substring-search-up
    if [[ -n ${terminfo[kcuu1]:-} ]]; then
        bindkey "$terminfo[kcuu1]" history-substring-search-up
    fi
fi
if (( ${+widgets[history-substring-search-down]} )); then
    bindkey '^[[B' history-substring-search-down
    if [[ -n ${terminfo[kcud1]:-} ]]; then
        bindkey "$terminfo[kcud1]" history-substring-search-down
    fi
fi

unset _dotfiles_fzf _dotfiles_mise _dotfiles_fzf_tab _dotfiles_hook
