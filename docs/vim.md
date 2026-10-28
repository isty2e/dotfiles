# Vim setup and recovery

`home/dot_vimrc` works without an existing `~/.vim` directory. It declares
vim-plug, plugins, three personal colorschemes and indentation settings for HTML,
Python, Ruby, Rust and Swift. Vim and Neovim keep separate configurations.

Use Vim 8.2+ with `+eval` for the declared plugins. Setup also needs Git, curl with
HTTPS support, and network access to GitHub and plugin download hosts. It needs
no administrator rights.

## Install

**Setup writes to `~/.vim`, including a symlink's destination.** Follow the
[migration guide](editor-migration.md#vim) before using an existing shared or
cloud-synced runtime.

For a new account, run from the checkout root:

```sh
cp -n home/dot_vimrc "$HOME/.vimrc"
vim
```

Run `:VimSetup`, inspect its output and `:PlugStatus`, then restart Vim. Use the
actual Vim executable, not an alias for Neovim. To select this vimrc without
replacing an existing one, run `vim -u "$PWD/home/dot_vimrc"`. Use a separate home
for an isolated trial; selecting a vimrc alone does not isolate the runtime.

Ordinary startup downloads nothing. It warns if the manager or plugins are
missing. If codedark is unavailable, Vim keeps core editing with its default
colorscheme. Fixed Colemak bindings follow [the keymap policy](keymaps.md).

## What setup changes

Each `:VimSetup` fetches the latest vim-plug from upstream `master`. It replaces
the manager if the content differs, acquires missing personal color files,
reloads the manager and runs `PlugInstall --sync` in `~/.vim/plugged`. The
personal color sources are pinned; the manager and plugin versions are not.
Future upstream changes may need configuration updates.

Setup executes third-party plugin code and fzf's binary installer. The fzf hook
uses `--bin`, so it does not edit shell startup files. Setup does not run
`PlugUpdate` or `PlugClean`. External tools such as Ruff, isort, language runtimes
and other ALE executables must be installed separately. Recovery does not restore
editing history or caches.

Existing personal color files are kept. Empty or unreadable color files stop
setup. Failed or empty manager downloads preserve the installed manager and stop
the operation; setup does not continue with an older manager. Downloads are
staged beside their targets so failed transfers do not publish partial files.
After fixing a plugin hook failure, use vim-plug's explicit forced-install retry
if needed. A present plugin checkout does not prove that its build succeeded.

## Restore the previous manager

Before replacing a different manager, setup saves its exact contents in
`~/.vim/autoload/plug.vim.old`. An identical download leaves that backup alone.
First installation makes no backup. Missing or empty manager files count as
uninstalled and do not replace an existing backup.

A failed backup write stops replacement. Setup publishes the backup before the
manager, not in one transaction: if manager replacement then fails, the active
manager remains and `.old` may contain the same version. The backup is the previous
file, not a known-good release. There is no automatic rollback.

To restore it, close Vim, copy the backup and restart:

```sh
cp "$HOME/.vim/autoload/plug.vim.old" "$HOME/.vim/autoload/plug.vim"
```

The next `:VimSetup` tries the latest upstream manager again.

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

Network or upstream incompatibility is a failure in that tier. Neither tier
installs the declared plugins or checks their full runtime compatibility.

For native keymap and NERDTree checks, use a terminal with an existing
vim-plug/NERDTree runtime:

```sh
sh tests/keymaps/run-vim.sh
```

Set `VIM_TEST_BINARY` to select Vim and `VIM_TEST_RUNTIME` to select a runtime.
The runner uses temporary home/XDG state, borrows cached plugins and does not run
`:VimSetup`. Missing prerequisites or a non-terminal invocation exit with code 77.
It checks movement, operators, literal input, window keys and NERDTree through
their effects. Ex-only startup is not a substitute for this terminal test.
