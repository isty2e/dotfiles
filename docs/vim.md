# Vim setup and recovery

`config/vim/vimrc` runs without an existing `~/.vim` directory and keeps Vim
separate from Neovim. It configures vim-plug, plugins, three personal colorschemes
and indentation for HTML, Python, Ruby, Rust and Swift.

Use Vim 8.2+ with `+eval`, Git, HTTPS-capable curl and access to GitHub/plugin
download hosts. No administrator rights are needed.

## Install

> [!WARNING]
> Setup writes to `~/.vim`, including a symlink's destination. Prepare existing
> shared or cloud-synced runtimes with the [migration guide](editor-migration.md#vim).

If mise has placed `~/.vimrc`, open Vim directly. For standalone setup on a new
account, run from the checkout root:

```sh
cp -n config/vim/vimrc "$HOME/.vimrc"
vim
```

1. Run `:VimSetup` using actual Vim, not an alias for Neovim.
2. Inspect the output and `:PlugStatus`, then restart Vim.

To select this vimrc without replacing yours, use `vim -u "$PWD/config/vim/vimrc"`.
Use a separate home for an isolated trial: `-u` alone does not isolate `~/.vim`.

Normal startup downloads nothing and warns if the manager or plugins are missing.
Without codedark, Vim uses its default colorscheme. Fixed Colemak bindings follow
[the keymap policy](keymaps.md).

## What setup changes

| Item | Action |
| --- | --- |
| vim-plug manager | Fetch latest upstream `master`; replace differing content, then reload it. |
| Personal colors | Acquire missing files from pinned sources; keep existing files. |
| Plugins | Run `PlugInstall --sync` in `~/.vim/plugged`, not `PlugUpdate` or `PlugClean`. |
| fzf | Run its binary installer with `--bin`; shell startup files are not edited. |
| External tools | Install Ruff, isort, language runtimes and other ALE executables separately. |

Setup runs third-party plugin code. Manager/plugin versions are not pinned, so
upstream changes may require configuration updates.

| If setup stops | What to do |
| --- | --- |
| Failed or empty manager download | Fix the download error and rerun setup. The installed manager is kept; no partial download is published and setup does not continue with the old manager. |
| Empty or unreadable personal color file | Inspect and repair that file before retrying. |
| Plugin install/build hook failure | Fix the cause, then use vim-plug's explicit forced-install retry if needed. A checkout's presence does not mean its build succeeded. |

## Restore the previous manager

Setup saves a differing installed manager's exact contents to
`~/.vim/autoload/plug.vim.old` before replacement. Identical downloads leave the
backup alone; a first install or missing/empty manager does not replace it.

| Failure | Files left in place |
| --- | --- |
| Backup write fails | Manager replacement stops. |
| Manager replacement fails after backup | The active manager remains; `.old` can contain that same version. |

The backup is the previous file, not a known-good release. To restore it manually,
close Vim, copy it back, then restart:

```sh
cp "$HOME/.vim/autoload/plug.vim.old" "$HOME/.vim/autoload/plug.vim"
```

This restores only the manager, not plugins, editing history or caches. The next
`:VimSetup` tries the latest upstream manager again.

## Tests

With the [test prerequisites](../setup.md#tests), run offline workflow and failure
tests from the checkout root. They use real Vim with download/installation doubles:

```sh
python tests/vim/test_recovery.py VimRecoveryTests -v
```

To include the real-manager tests, which fetch the latest vim-plug once:

```sh
python -m unittest discover -s tests/vim -v
```

Network or upstream incompatibility fails that tier. Neither tier installs the
declared plugins or checks their full runtime compatibility.

For native keymap and NERDTree checks, use a terminal with an existing
vim-plug/NERDTree runtime:

```sh
sh tests/keymaps/run-vim.sh
```

Set `VIM_TEST_BINARY` to select Vim and `VIM_TEST_RUNTIME` to select a runtime.
The runner uses temporary home/XDG state and cached plugins without `:VimSetup`.
It checks movement, operators, literal input, window keys and NERDTree. Missing
prerequisites or a non-terminal invocation exit with code 77; use a terminal,
not Ex-only startup, for these checks.
