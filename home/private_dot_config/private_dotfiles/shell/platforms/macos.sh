alias ls='ls -G'

# Preserve the historical profile default; device settings can choose otherwise.
DOTFILES_ZSH_HISTORY_SIZE=${DOTFILES_ZSH_HISTORY_SIZE:-4096}
DOTFILES_BASH_HISTORY_SYNC=${DOTFILES_BASH_HISTORY_SYNC:-1}

if command -v xcode-select >/dev/null 2>&1 &&
    command -v xcrun >/dev/null 2>&1 && xcode-select -p >/dev/null 2>&1; then
    if _dotfiles_sdk=$(xcrun --show-sdk-path 2>/dev/null) && [ -n "$_dotfiles_sdk" ]; then
        case :${CPATH-}: in
            *:"$_dotfiles_sdk/usr/include":*) ;;
            *) export CPATH="$_dotfiles_sdk/usr/include${CPATH:+:$CPATH}" ;;
        esac
    fi
fi
unset _dotfiles_sdk
