# Machine-specific settings are trusted local shell code shared by Bash and Zsh.
if [ -r "$HOME/.config/dotfiles/local.sh" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.config/dotfiles/local.sh"
fi

# Cluster credentials are separate from non-secret machine settings.
_dotfiles_load_credentials() {
    local _dotfiles_file _dotfiles_mode _dotfiles_owner _dotfiles_allexport _dotfiles_status
    _dotfiles_file="$HOME/.config/dotfiles/credentials.sh"
    [ -e "$_dotfiles_file" ] || return 0

    _dotfiles_mode=$(stat -c '%a' -- "$_dotfiles_file" 2>/dev/null) || _dotfiles_mode=
    _dotfiles_owner=$(stat -c '%u' -- "$_dotfiles_file" 2>/dev/null) || _dotfiles_owner=
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

if [ "$(uname -s)" = Linux ]; then
    _dotfiles_load_credentials
fi
unset -f _dotfiles_load_credentials
