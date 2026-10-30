# Dotfiles

Personal shell, editor and tool configuration for macOS and Linux. Mise links
configuration files and prepares command-line tools; Pixi manages the scientific
Python environment. Vim and Neovim have independent configurations.

**For an existing home, review the configuration and back up startup files before
applying.** Follow [first-apply preparation](setup.md#first-apply-on-an-existing-home)
to preserve existing files and keep private shell values out of Git. If your
editors use links or a shared runtime, follow the
[migration guide](docs/editor-migration.md) first. Linked source edits become live
without another apply; new files and links still need deployment.

Install [mise](https://mise.jdx.dev/getting-started.html), Git and HTTPS-capable
curl first. Bootstrap enables the optional
[Claude Code summary hook](setup.md#claude-code-agent-summary-preload) by default;
see its setup section if you want it off.

```sh
git clone https://github.com/isty2e/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
mise trust mise.toml &&
  mise dot apply &&
  mise trust "$HOME/.config/mise/conf.d/tools.toml" &&
  mise bootstrap
```

- [Setup](setup.md): bootstrap, additional installations and existing-home preparation.
- [Configuration reference](docs/manifest-management.md): where to edit, shell
  defaults, private files and when changes take effect.
- [Vim](docs/vim.md) and [Neovim](docs/neovim.md): explicit plugin setup and recovery.
- [Colemak keymaps](docs/keymaps.md): shared keys and editor-specific bindings.
- [Pi PaperColor themes](pi/README.md): optional theme installation.

Run `sh tests/run.sh` for offline checks. See [test prerequisites](setup.md#tests)
before running them; plugin-loaded and network-backed checks are separate.
