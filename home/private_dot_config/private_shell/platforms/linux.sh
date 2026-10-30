alias ls='ls --color=auto'
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
if [ -d /usr/lib/locale ]; then export LOCPATH=/usr/lib/locale; fi

# Preserve the historical profile default; this does not identify a cluster.
DOTFILES_ZSH_HISTORY_SIZE=${DOTFILES_ZSH_HISTORY_SIZE:-1024}
DOTFILES_BASH_HISTORY_SYNC=${DOTFILES_BASH_HISTORY_SYNC:-0}
