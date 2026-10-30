# Environment activation is only for interactive shells.
case $- in
    *i*) ;;
    *) return ;;
esac

if [ -n "${ZSH_VERSION:-}" ]; then
    _dotfiles_shell=zsh
else
    _dotfiles_shell=bash
fi

_dotfiles_executable() {
    if [ "$_dotfiles_shell" = zsh ]; then
        whence -p "$1"
    else
        type -P "$1"
    fi
}

# Activate already-prepared mise tools without running an installer here.
_dotfiles_mise=$(_dotfiles_executable mise 2>/dev/null) || _dotfiles_mise=
if [ -n "$_dotfiles_mise" ] && [ -x "$_dotfiles_mise" ]; then
    if _dotfiles_hook=$(MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false \
        "$_dotfiles_mise" activate "$_dotfiles_shell"); then
        eval "$_dotfiles_hook"
    fi
fi

# Do not replace an environment inherited from a project or another shell.
if [ -z "${PIXI_PROJECT_MANIFEST:-}" ] && [ -z "${CONDA_PREFIX:-}" ] &&
    [ -z "${VIRTUAL_ENV:-}" ]; then
    _dotfiles_manifest=
    if [ -n "${DOTFILES_PIXI_BASE_MANIFEST:-}" ]; then
        _dotfiles_manifest=$DOTFILES_PIXI_BASE_MANIFEST
    elif [ -n "${PIXI_ENVS_HOME:-}" ]; then
        _dotfiles_manifest="$PIXI_ENVS_HOME/base/pixi.toml"
    elif [ -r "$HOME/.config/shell/workspaces.sh" ]; then
        # shellcheck source=/dev/null
        . "$HOME/.config/shell/workspaces.sh"
        _dotfiles_manifest=${_dotfiles_repository_manifest:-}
    fi

    case $_dotfiles_manifest in
        */*) _dotfiles_base=${_dotfiles_manifest%/*} ;;
        *) _dotfiles_base=. ;;
    esac

    # Resolve a real installed Pixi, not a mise shim that could auto-install it.
    _dotfiles_pixi=
    if [ -n "$_dotfiles_mise" ] && [ -x "$_dotfiles_mise" ]; then
        _dotfiles_pixi=$(MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false \
            "$_dotfiles_mise" which pixi 2>/dev/null) || _dotfiles_pixi=
    fi
    if [ -z "$_dotfiles_pixi" ]; then
        _dotfiles_pixi=$(_dotfiles_executable pixi 2>/dev/null) || _dotfiles_pixi=
    fi

    if [ -n "$_dotfiles_pixi" ] && [ -x "$_dotfiles_pixi" ] &&
        { [ -z "$_dotfiles_mise" ] || [ ! "$_dotfiles_pixi" -ef "$_dotfiles_mise" ]; } &&
        [ -f "$_dotfiles_manifest" ] && [ -d "$_dotfiles_base/.pixi/envs/default" ]; then
        if _dotfiles_hook=$(MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false \
            "$_dotfiles_pixi" shell-hook --as-is --manifest-path "$_dotfiles_manifest" \
            --shell "$_dotfiles_shell"); then
            eval "$_dotfiles_hook"
        fi
    fi
fi

unset _dotfiles_shell _dotfiles_mise _dotfiles_hook _dotfiles_manifest _dotfiles_base _dotfiles_pixi _dotfiles_repository_manifest
unset -f _dotfiles_executable
