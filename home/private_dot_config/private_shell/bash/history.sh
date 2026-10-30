# Defaults and device choices are already set by .bashrc. Only compose behavior.
# Prompt-time writes are opt-in, regardless of OS or filesystem guesses.
if [ "${DOTFILES_BASH_HISTORY_SYNC:-0}" = 1 ]; then
    _dotfiles_history_sync() {
        local _dotfiles_status=$?
        history -a
        history -n
        return "$_dotfiles_status"
    }

    # Compose with mise and other prompt commands, including Bash's array form.
    if [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == 'declare -a'* ]]; then
        _dotfiles_history_present=no
        for _dotfiles_prompt in "${PROMPT_COMMAND[@]}"; do
            [[ $_dotfiles_prompt == _dotfiles_history_sync ]] && _dotfiles_history_present=yes
        done
        if [[ $_dotfiles_history_present == no ]]; then
            PROMPT_COMMAND+=( _dotfiles_history_sync )
        fi
        unset _dotfiles_history_present _dotfiles_prompt
    else
        # The array case was handled above; older Bash uses a scalar here.
        # shellcheck disable=SC2128,SC2178
        case ";${PROMPT_COMMAND:-};" in
            *';_dotfiles_history_sync;'*) ;;
            *) PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}_dotfiles_history_sync" ;;
        esac
    fi
fi

# Older Readline versions keep their native history keys.
if bind -l | grep -qx history-substring-search-backward &&
    bind -l | grep -qx history-substring-search-forward; then
    bind '"\e[A": history-substring-search-backward'
    bind '"\e[B": history-substring-search-forward'
fi
