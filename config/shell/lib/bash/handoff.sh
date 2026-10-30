# Non-interactive commands and jobs must continue in the configured shell.
case $- in
    *i*) ;;
    *) return ;;
esac

# Bootstrap tools may be installed here before mise is active.
case :$PATH: in
    *:"$HOME/.local/bin":*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH

# A remote Linux login normally enters Zsh; child Bash sessions may opt out.
if [ "$(uname -s)" = Linux ] && [ -n "${SSH_CONNECTION:-}" ] &&
    [ "${DOTFILES_KEEP_BASH:-}" != 1 ] && [ "${DOTFILES_ZSH_ACTIVE:-}" != 1 ]; then
    _dotfiles_zsh=$(type -P zsh 2>/dev/null) || _dotfiles_zsh=
    _dotfiles_mise=$(type -P mise 2>/dev/null) || _dotfiles_mise=
    if [ -n "$_dotfiles_zsh" ] && [ -n "$_dotfiles_mise" ] &&
        [ "$_dotfiles_zsh" -ef "$_dotfiles_mise" ]; then
        _dotfiles_zsh=$(MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false \
            "$_dotfiles_mise" which zsh 2>/dev/null) || _dotfiles_zsh=
    fi

    if [ -n "$_dotfiles_zsh" ] && [ -x "$_dotfiles_zsh" ] &&
        { [ -z "$_dotfiles_mise" ] || [ ! "$_dotfiles_zsh" -ef "$_dotfiles_mise" ]; }; then
        _dotfiles_previous_marker=${DOTFILES_ZSH_ACTIVE-}
        _dotfiles_marker_was_set=${DOTFILES_ZSH_ACTIVE+x}
        if shopt -q execfail; then _dotfiles_execfail_was_set=yes; else _dotfiles_execfail_was_set=no; fi
        shopt -s execfail
        export DOTFILES_ZSH_ACTIVE=1
        SHELL=$_dotfiles_zsh exec "$_dotfiles_zsh"
        if [ "$_dotfiles_execfail_was_set" = no ]; then shopt -u execfail; fi
        if [ -n "$_dotfiles_marker_was_set" ]; then
            export DOTFILES_ZSH_ACTIVE=$_dotfiles_previous_marker
        else
            unset DOTFILES_ZSH_ACTIVE
        fi
    fi
fi

unset _dotfiles_zsh _dotfiles_mise _dotfiles_previous_marker _dotfiles_marker_was_set _dotfiles_execfail_was_set
