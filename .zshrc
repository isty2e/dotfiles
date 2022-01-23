autoload -U compinit && compinit
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

    #zgen oh-my-zsh

    # plugins
    zgen oh-my-zsh plugins/python
    zgen oh-my-zsh plugins/pip
    zgen oh-my-zsh plugins/ruby
    zgen oh-my-zsh plugins/gem
    zgen oh-my-zsh plugins/asdf
    zgen oh-my-zsh plugins/extract
    zgen oh-my-zsh plugins/rsync
    zgen oh-my-zsh plugins/git
    zgen oh-my-zsh plugins/dirhistory
    zgen oh-my-zsh plugins/brew
    zgen oh-my-zsh plugins/brew-cask
    zgen oh-my-zsh plugins/osx
    zgen oh-my-zsh plugins/textmate
    zgen oh-my-zsh plugins/marked2

    zgen load zsh-users/zsh-syntax-highlighting
    zgen load zsh-users/zsh-history-substring-search
    zgen load Tarrasch/zsh-bd
    zgen load Tarrasch/zsh-mcd
    zgen load Tarrasch/zsh-command-not-found

    # completions
    zgen load zsh-users/zsh-completions src

    # save all to init script
    zgen save
fi

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

# basic commands
#alias rm="rm -i"
#alias cp="cp -i"
#alias mv="mv -i"

# rsync
#alias cpv="rsync -poghb --backup-dir=/home/$USER/rsync -e /dev/null --progress --"
alias cpv="rsync -poghb --backup-dir=/home/$USER/rsync --progress --"
alias rscp="rsync -avz --progress -h"
alias rsmv="rsync -avz --progress -h --remove-source-files"
alias rsup="rsync -avzu --progress -h"
alias rssync="rsync -avzu --delete --progress -h"

alias grep='grep --color'
alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS} '

# ..
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'

# vim
alias vim='nvim'
alias vi='nvim'
alias v='nvim -p'

# pplatex
alias ppl='ppdflatex'
alias ppll='pplatex -c /Library/TeX/texbin/lualatex --'

# cpath
export CPATH=`xcrun --show-sdk-path`/usr/include

# homebrew
export PATH=/usr/local/sbin:$PATH

# homebrew cask
#export HOMEBREW_CASK_OPTS="--appdir=/Applications --caskroom=/etc/Caskroom"

# pip update all packages
alias pipup="pip freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip install -U"

# pyscf
# export PYTHONPATH=/Users/isty2e/Desktop/pyscf-1.3:$PYTHONPATH

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
