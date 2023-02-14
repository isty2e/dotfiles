# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

autoload -U promptinit && promptinit
prompt walters

export HISTSIZE=1024
export SAVEHIST=$HISTSIZE
export HISTFILE="$HOME/.zsh_history"
setopt append_history
setopt hist_ignore_all_dups
setopt hist_expire_dups_first
setopt inc_append_history
setopt share_history

setopt always_to_end
setopt complete_in_word
setopt correct

setopt extendedglob
setopt glob_complete

setopt auto_cd
setopt auto_remove_slash
setopt chase_links

setopt list_rows_first

zstyle ':completion:*' group-name ''
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:default' select-prompt '%SMatch %M %P%s'
zstyle ':completion:::::' completer _complete _approximate
zstyle ':completion:*:descriptions' format "%{$bg_bold[green]%}%S%d%s%{$reset_color%}"
zstyle ':completion:*:approximate:*' max-errors 2

# zgen
source "$HOME/zgen/zgen.zsh"

# check if there's no init script
if ! zgen saved; then
    echo "Creating a zgen save"

    # powerlevel10k
    zgen load romkatv/powerlevel10k powerlevel10k

    #zgen oh-my-zsh

    # plugins
    zgen oh-my-zsh plugins/extract
    zgen oh-my-zsh plugins/rsync
    zgen oh-my-zsh plugins/dirhistory
    zgen oh-my-zsh plugins/brew
    zgen oh-my-zsh plugins/macos

    # fish-like
    zgen load zsh-users/zsh-autosuggestions
    zgen load zsh-users/zsh-syntax-highlighting
    zgen load zsh-users/zsh-history-substring-search

    # some comfy stuff
    zgen load Tarrasch/zsh-bd
    zgen load Tarrasch/zsh-mcd
    zgen load Tarrasch/zsh-command-not-found
    zgen load chrissicool/zsh-256color

    # completions
    zgen load zsh-users/zsh-completions src
    zgen load Aloxaf/fzf-tab

    # save all to init script
    zgen save
fi

autoload -U compinit && compinit

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#808080"

# substring search
# bind UP and DOWN arrow keys
zmodload zsh/terminfo
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# alias

# ls
alias ls='ls -G'
alias l='ls -Glh'
alias ll='ls -Glh'
alias lla='ls -Glah'

# rsync
alias cpv="rsync -poghb --backup-dir=/home/$USER/rsync --info=progress2 --"
alias rscp="rsync -avz --info=progress2 -h"
alias rsmv="rsync -avz --info=progress2 -h --remove-source-files"
alias rsup="rsync -avzu --info=progress2 -h"
alias rssync="rsync -avzu --delete --info=progress2 -h"

alias grep='grep --color'
alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS} '

# ..
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'

# vim
if command -v nvim &> /dev/null
then
    alias vim='nvim'
fi
alias vi='nvim'
alias v='nvim -p'

# cpath
export CPATH=`xcrun --show-sdk-path`/usr/include

# <<< conda initialize <<<

# nnn
n ()
{
    # Block nesting of nnn in subshells
    if [[ "${NNNLVL:-0}" -ge 1 ]]; then
        echo "nnn is already running"
        return
    fi

    # The behaviour is set to cd on quit (nnn checks if NNN_TMPFILE is set)
    # If NNN_TMPFILE is set to a custom path, it must be exported for nnn to
    # see. To cd on quit only on ^G, remove the "export" and make sure not to
    # use a custom path, i.e. set NNN_TMPFILE *exactly* as follows:
    #     NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
    export NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"

    # Unmask ^Q (, ^V etc.) (if required, see `stty -a`) to Quit nnn
    # stty start undef
    # stty stop undef
    # stty lwrap undef
    # stty lnext undef

    # The backslash allows one to alias n to nnn if desired without making an
    # infinitely recursive alias
    \nnn "$@"

    if [ -f "$NNN_TMPFILE" ]; then
            . "$NNN_TMPFILE"
            rm -f "$NNN_TMPFILE" > /dev/null
    fi
}

# iterm
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_COMMAND='fd --type f'

