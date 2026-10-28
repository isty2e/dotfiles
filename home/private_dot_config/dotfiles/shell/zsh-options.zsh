# Keep separate Zsh history with the existing platform-specific retention.
case $(uname -s) in
    Darwin) HISTSIZE=4096 ;;
    *) HISTSIZE=1024 ;;
esac
SAVEHIST=$HISTSIZE
HISTFILE="$HOME/.zsh_history"
setopt append_history hist_ignore_all_dups hist_expire_dups_first share_history

# Preserve the existing editing and navigation behavior without correction prompts.
setopt always_to_end complete_in_word extendedglob glob_complete
setopt auto_cd auto_remove_slash chase_links list_rows_first
unsetopt correct
