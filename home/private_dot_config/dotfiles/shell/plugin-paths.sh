# Use only a fully prepared Sheldon generation.
_dotfiles_generation_dir=
_dotfiles_generation_pointer="$HOME/.local/share/dotfiles/sheldon/current"
if [ -f "$_dotfiles_generation_pointer" ] && [ ! -L "$_dotfiles_generation_pointer" ]; then
    IFS= read -r _dotfiles_generation < "$_dotfiles_generation_pointer" || _dotfiles_generation=
    case $_dotfiles_generation in
        generation.*)
            case $_dotfiles_generation in
                *[!a-zA-Z0-9._-]*|generation.) ;;
                *)
                    _dotfiles_candidate="$HOME/.local/share/dotfiles/sheldon/generations/$_dotfiles_generation"
                    if [ -r "$_dotfiles_candidate/zsh-plugins.zsh" ]; then
                        _dotfiles_generation_dir=$_dotfiles_candidate
                    fi
                    ;;
            esac
            ;;
    esac
fi
unset _dotfiles_generation_pointer _dotfiles_generation _dotfiles_candidate
