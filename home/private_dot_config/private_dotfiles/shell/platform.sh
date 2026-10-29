# Only operating-system defaults belong here; device code runs afterwards.
_dotfiles_platform_root=${_dotfiles_shell_dir:-$HOME/.config/dotfiles/shell}
case $(uname -s) in
    Darwin) _dotfiles_platform_file=macos.sh ;;
    Linux) _dotfiles_platform_file=linux.sh ;;
    *) _dotfiles_platform_file= ;;
esac
if [ -n "$_dotfiles_platform_file" ] &&
    [ -r "$_dotfiles_platform_root/platforms/$_dotfiles_platform_file" ]; then
    # shellcheck source=/dev/null
    . "$_dotfiles_platform_root/platforms/$_dotfiles_platform_file"
fi
unset _dotfiles_platform_file _dotfiles_platform_root
