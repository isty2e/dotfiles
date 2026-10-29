# Editors
export EDITOR=hx
export VISUAL=hx

unalias vim 2>/dev/null || :
alias vi='vim'
alias v='nvim -p'

# Pi clipboard
export PI_CLIPBOARD_OSC52=1

# Directory listings
case $(uname -s) in
    Darwin) alias ls='ls -G' ;;
    Linux) alias ls='ls --color=auto' ;;
esac

alias l='ls -lh'
alias ll='ls -lh'
alias lla='ls -lah'

# Search helpers
alias grep='grep --color'
alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS} '

# File transfers
alias cpv='rsync -poghb --backup-dir="${DOTFILES_RSYNC_BACKUP_DIR:-/home/$USER/rsync}" --info=progress2 --'
alias rscp='rsync -avz --info=progress2 -h'
alias rsmv='rsync -avz --info=progress2 -h --remove-source-files'
alias rsup='rsync -avzu --info=progress2 -h'
alias rssync='rsync -avzu --delete --info=progress2 -h'

# Use the same archive extractor in Bash without duplicating its format handling.
if [ -n "${BASH_VERSION:-}" ]; then
    extract() {
        local plugin="${_dotfiles_generation_dir:-}/repos/github.com/ohmyzsh/ohmyzsh/plugins/extract/extract.plugin.zsh"
        if [ -z "${_dotfiles_generation_dir:-}" ] || [ ! -r "$plugin" ] || ! command -v zsh >/dev/null 2>&1; then
            printf '%s\n' 'extract: the prepared extract plugin and zsh are required' >&2
            return 1
        fi

        command zsh -f -c 'source "$1" || exit; shift; extract "$@"' dotfiles-extract "$plugin" "$@"
    }
    alias x='extract'
fi

# Directory navigation
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'

mcd() {
    [ "$#" -eq 1 ] || return 2
    mkdir -p -- "$1" || return
    cd -- "$1" || return
}

n() {
    command nnn "$@"
}

# Slurm output
export SQUEUE_FORMAT='%.12i %.9P %.20j %.12u %.4Q %.2T %.10M %.9l %.6D %R'
alias jobinfo='scontrol show jobid -dd'
