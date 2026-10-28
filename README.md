# Dotfiles

Personal shell, editor and tool configuration for macOS and Linux. Chezmoi places
configuration files, mise installs command-line tools, and Pixi manages the
scientific Python environment. Vim and Neovim have independent configurations.

**For an existing home, review the configuration and back up startup files before
applying.** Follow [first-apply preparation](setup.md#first-apply-on-an-existing-home)
to keep private shell values out of Git. Do not bulk `re-add` before that first
reviewed apply or when newly managed files appear. If your editors use links or
a shared runtime, follow the
[migration guide](docs/editor-migration.md) first. Bootstrap replaces managed
`.bashrc` and `.zshrc` files and downloads tools and shell plugins.

With Git, a POSIX shell and HTTPS-capable curl installed:

```sh
git clone https://github.com/isty2e/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
sh bootstrap.sh
```

- [Setup](setup.md): shell settings, tools, Pixi and tests.
- [Edit and capture configuration](docs/manifest-management.md): bring local edits
  back into Git with `chezmoi re-add`.
- [Vim](docs/vim.md) and [Neovim](docs/neovim.md): explicit plugin setup and recovery.
- [Colemak keymaps](docs/keymaps.md): shared keys and editor-specific bindings.
- [Pi PaperColor themes](pi/README.md): optional theme installation.

Run `sh tests/run.sh` for offline checks. See [test prerequisites](setup.md#tests)
before running them; plugin-loaded and network-backed checks are separate.
