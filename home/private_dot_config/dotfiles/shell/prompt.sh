# Prompt initialization is interactive and never installs missing tools.
case $- in
    *i*) ;;
    *) return 0 ;;
esac

if [ -n "${BASH_VERSION:-}" ]; then
    _dotfiles_prompt_shell=bash
    _dotfiles_starship=$(type -P starship 2>/dev/null) || _dotfiles_starship=
    _dotfiles_mise=$(type -P mise 2>/dev/null) || _dotfiles_mise=
elif [ -n "${ZSH_VERSION:-}" ]; then
    _dotfiles_prompt_shell=zsh
    _dotfiles_starship=$(whence -p starship 2>/dev/null) || _dotfiles_starship=
    _dotfiles_mise=$(whence -p mise 2>/dev/null) || _dotfiles_mise=
else
    return 0
fi

if [ -n "$_dotfiles_starship" ] && [ -x "$_dotfiles_starship" ] &&
    { [ -z "$_dotfiles_mise" ] || [ ! "$_dotfiles_starship" -ef "$_dotfiles_mise" ]; }; then
    if _dotfiles_prompt_init=$(MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false \
        "$_dotfiles_starship" init "$_dotfiles_prompt_shell"); then
        eval "$_dotfiles_prompt_init"
    fi
fi

unset _dotfiles_prompt_shell _dotfiles_starship _dotfiles_mise _dotfiles_prompt_init
