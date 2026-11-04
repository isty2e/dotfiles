_dotfiles_active_prefix=${VIRTUAL_ENV:-${CONDA_PREFIX:-}}
if [ -n "$_dotfiles_active_prefix" ] && [ -d "$_dotfiles_active_prefix/bin" ]; then
    export PATH="$_dotfiles_active_prefix/bin:$PATH"
fi
unset _dotfiles_active_prefix
