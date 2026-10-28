# Initialize an existing Homebrew installation before mise changes PATH.
_dotfiles_brew=${BREW_LOCATION:-}
if [ -n "${ZSH_VERSION:-}" ]; then
    _dotfiles_mise=$(whence -p mise 2>/dev/null) || _dotfiles_mise=
else
    _dotfiles_mise=$(type -P mise 2>/dev/null) || _dotfiles_mise=
fi
if [ -z "$_dotfiles_brew" ]; then
    if [ -n "${ZSH_VERSION:-}" ]; then
        _dotfiles_brew=$(whence -p brew 2>/dev/null) || _dotfiles_brew=
    else
        _dotfiles_brew=$(type -P brew 2>/dev/null) || _dotfiles_brew=
    fi
fi
if [ -z "$_dotfiles_brew" ]; then
    for _dotfiles_candidate in /opt/homebrew/bin/brew /usr/local/bin/brew \
        "$HOME/homebrew/bin/brew" "$HOME/.linuxbrew/bin/brew"; do
        if [ -x "$_dotfiles_candidate" ]; then
            _dotfiles_brew=$_dotfiles_candidate
            break
        fi
    done
fi
if [ -n "$_dotfiles_brew" ] && [ -x "$_dotfiles_brew" ] &&
    { [ -z "$_dotfiles_mise" ] || [ ! "$_dotfiles_brew" -ef "$_dotfiles_mise" ]; }; then
    if _dotfiles_brew_env=$(MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false \
        "$_dotfiles_brew" shellenv); then
        eval "$_dotfiles_brew_env"
    fi
fi

_dotfiles_brew_plugin=
if [ -n "${_dotfiles_generation_dir:-}" ]; then
    _dotfiles_brew_plugin="$_dotfiles_generation_dir/repos/github.com/ohmyzsh/ohmyzsh/plugins/brew/brew.plugin.zsh"
fi
if [ -n "${ZSH_VERSION:-}" ] && [ -n "${HOMEBREW_PREFIX:-}" ] && [ -r "$_dotfiles_brew_plugin" ]; then
    # shellcheck source=/dev/null
    . "$_dotfiles_brew_plugin" || :
fi

# Linux locale and the macOS SDK include path follow the supplied profiles.
case $(uname -s) in
    Linux)
        export LANG=C.UTF-8
        export LC_ALL=C.UTF-8
        if [ -d /usr/lib/locale ]; then export LOCPATH=/usr/lib/locale; fi
        ;;
    Darwin)
        if command -v xcode-select >/dev/null 2>&1 &&
            command -v xcrun >/dev/null 2>&1 && xcode-select -p >/dev/null 2>&1; then
            if _dotfiles_sdk=$(xcrun --show-sdk-path 2>/dev/null) && [ -n "$_dotfiles_sdk" ]; then
                case :${CPATH-}: in
                    *:"$_dotfiles_sdk/usr/include":*) ;;
                    *) export CPATH="$_dotfiles_sdk/usr/include${CPATH:+:$CPATH}" ;;
                esac
            fi
        fi
        ;;
esac

unset _dotfiles_brew _dotfiles_mise _dotfiles_candidate _dotfiles_brew_env _dotfiles_brew_plugin _dotfiles_sdk
