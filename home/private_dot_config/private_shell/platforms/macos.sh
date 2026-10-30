alias ls='ls -G'

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
