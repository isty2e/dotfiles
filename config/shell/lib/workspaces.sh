_dotfiles_repository_manifest=
if [ -L "$HOME/.config/mise" ]; then
    _dotfiles_workspaces=$(CDPATH='' cd -P "$HOME/.config/mise/.." 2>/dev/null && pwd) ||
        _dotfiles_workspaces=
    if [ -n "$_dotfiles_workspaces" ]; then
        _dotfiles_repository_manifest="$_dotfiles_workspaces/pixi-base/pixi.toml"
    fi
    unset _dotfiles_workspaces
fi
