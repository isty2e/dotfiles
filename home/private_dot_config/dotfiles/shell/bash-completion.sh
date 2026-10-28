# This fragment is for interactive Bash; scripts and jobs keep their own setup.
case $- in
    *i*) ;;
    *) return ;;
esac

# Initialize the standard fzf shortcuts even when fuzzy Tab is unavailable.
_dotfiles_fzf=$(type -P fzf 2>/dev/null) || _dotfiles_fzf=
_dotfiles_mise=$(type -P mise 2>/dev/null) || _dotfiles_mise=
if [ -n "$_dotfiles_fzf" ] && [ -x "$_dotfiles_fzf" ] &&
    { [ -z "$_dotfiles_mise" ] || [ ! "$_dotfiles_fzf" -ef "$_dotfiles_mise" ]; }; then
    if _dotfiles_fzf_init=$(MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false \
        "$_dotfiles_fzf" --bash); then
        eval "$_dotfiles_fzf_init"
    fi
fi
unset _dotfiles_fzf_init

# Current bash-completion supports Bash 4.2 and newer.
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2) )); then
    unset _dotfiles_fzf _dotfiles_mise
    return
fi

if [ -z "${_dotfiles_generation_dir:-}" ]; then
    unset _dotfiles_fzf _dotfiles_mise
    return
fi
_dotfiles_bash_completion="$_dotfiles_generation_dir/repos/github.com/scop/bash-completion/bash_completion"
_dotfiles_fzf_tab="$_dotfiles_generation_dir/repos/github.com/lincheney/fzf-tab-completion/bash/fzf-bash-completion.sh"

# Load command-specific candidates before installing the fuzzy Tab selector.
if [ -r "$_dotfiles_bash_completion" ]; then
    # shellcheck source=/dev/null
    . "$_dotfiles_bash_completion"
fi

_dotfiles_fzf_supported=yes
_dotfiles_tac=$(type -P tac 2>/dev/null) || _dotfiles_tac=
if [ -z "$_dotfiles_tac" ] ||
    { [ -n "$_dotfiles_mise" ] && [ "$_dotfiles_tac" -ef "$_dotfiles_mise" ]; }; then
    _dotfiles_fzf_supported=no
fi

if [ "$(uname -s)" = Darwin ]; then
    _dotfiles_awk=$(type -P gawk 2>/dev/null) || _dotfiles_awk=$(type -P awk 2>/dev/null) || _dotfiles_awk=
    if [ -z "$_dotfiles_awk" ] ||
        { [ -n "$_dotfiles_mise" ] && [ "$_dotfiles_awk" -ef "$_dotfiles_mise" ]; } ||
        ! MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false \
            "$_dotfiles_awk" -W interactive 'BEGIN { exit 0 }' </dev/null >/dev/null 2>&1; then
        _dotfiles_fzf_supported=no
    fi
fi

if [ "$_dotfiles_fzf_supported" = yes ] && [ -r "$_dotfiles_fzf_tab" ] &&
    [ -n "$_dotfiles_fzf" ] && [ -x "$_dotfiles_fzf" ] &&
    { [ -z "$_dotfiles_mise" ] || [ ! "$_dotfiles_fzf" -ef "$_dotfiles_mise" ]; }; then
    # shellcheck source=/dev/null
    if . "$_dotfiles_fzf_tab"; then
        bind -x '"\t": fzf_bash_completion'
    fi
fi

unset _dotfiles_bash_completion _dotfiles_fzf_tab _dotfiles_fzf_supported
unset _dotfiles_awk _dotfiles_tac _dotfiles_fzf _dotfiles_mise
