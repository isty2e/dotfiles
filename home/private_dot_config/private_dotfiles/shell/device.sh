# Device files are private runtime input, not checked-in source dependencies.
# shellcheck disable=SC1091

# Exactly one device file is loaded; never merge an old and new local profile.
if [ -e "$HOME/.config/dotfiles/device/local.sh" ] || [ -L "$HOME/.config/dotfiles/device/local.sh" ]; then
    if [ -r "$HOME/.config/dotfiles/device/local.sh" ]; then
        . "$HOME/.config/dotfiles/device/local.sh"
    fi
elif [ -r "$HOME/.config/dotfiles/local.sh" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.config/dotfiles/local.sh"
fi

# Credentials are private device data, not an operating-system property.
_dotfiles_load_credentials() {
    local _dotfiles_file _dotfiles_mode _dotfiles_owner _dotfiles_allexport _dotfiles_status
    _dotfiles_file=$1

    case $(uname -s) in
        Darwin)
            _dotfiles_mode=$(stat -f '%Lp' "$_dotfiles_file" 2>/dev/null) || _dotfiles_mode=
            _dotfiles_owner=$(stat -f '%u' "$_dotfiles_file" 2>/dev/null) || _dotfiles_owner=
            ;;
        *)
            _dotfiles_mode=$(stat -c '%a' -- "$_dotfiles_file" 2>/dev/null) || _dotfiles_mode=
            _dotfiles_owner=$(stat -c '%u' -- "$_dotfiles_file" 2>/dev/null) || _dotfiles_owner=
            ;;
    esac
    case $_dotfiles_mode in
        ''|*[!0-7]*) _dotfiles_mode=invalid ;;
        *00) ;;
        *) _dotfiles_mode=invalid ;;
    esac

    if [ "$_dotfiles_mode" = invalid ] || [ "$_dotfiles_owner" != "$(id -u)" ] || [ ! -r "$_dotfiles_file" ]; then
        printf 'Skipping inaccessible or insecure dotfiles credentials file.\n' >&2
        return 0
    fi

    case $- in
        *a*) _dotfiles_allexport=yes ;;
        *) _dotfiles_allexport=no ;;
    esac

    set -a
    # shellcheck source=/dev/null
    if . "$_dotfiles_file"; then
        _dotfiles_status=0
    else
        _dotfiles_status=$?
    fi

    if [ "$_dotfiles_allexport" = yes ]; then set -a; else set +a; fi
    if [ "$_dotfiles_status" -ne 0 ]; then
        printf 'Could not load dotfiles credentials.\n' >&2
    fi
}

if [ -e "$HOME/.config/dotfiles/device/credentials.sh" ] || [ -L "$HOME/.config/dotfiles/device/credentials.sh" ]; then
    _dotfiles_load_credentials "$HOME/.config/dotfiles/device/credentials.sh"
elif [ "$(uname -s)" = Linux ] && [ -e "$HOME/.config/dotfiles/credentials.sh" ]; then
    # The legacy path keeps its previous Linux-only execution scope.
    _dotfiles_load_credentials "$HOME/.config/dotfiles/credentials.sh"
fi
unset -f _dotfiles_load_credentials
