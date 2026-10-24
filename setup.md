# Settings

See [Colemak keymap policy](docs/keymaps.md). Execution and migration are tracked in Kata.

## dotfiles

```bash
git clone https://github.com/tarjoilija/zgen
ln -s dotfiles/.zshrc ~/.zshrc
ln -s dotfiles/.zshrc_linux ~/.zshrc
```

## Vim recovery

`home/dot_vimrc` is the standalone recovery entrypoint; an existing `.vim`
directory is not required. It declares vim-plug, plugins, three personal
colorschemes, and the HTML/Python/Ruby/Rust/Swift indentation settings. This vimrc does not start
downloads or installation during ordinary startup. A missing manager or plugin
directory produces a warning. If codedark is unavailable, Vim uses the default
colorscheme while keeping core editing available.

Recovery requires Vim 8.2+ with `+eval` for the declared plugins, Git, curl with
HTTPS support, and network access to GitHub and plugin download hosts. It needs
no administrator rights.
Every `:VimSetup` fetches the latest vim-plug from its official `master` branch
and updates the installed manager when the content differs. It acquires
missing personal color files into `~/.vim`, reloads the refreshed manager, then
runs vim-plug's synchronous installation under `~/.vim/plugged`. This executes
third-party plugin code and the fzf binary installer. The fzf hook uses `--bin`,
not shell integration; setup does not edit shell startup files.

Setup writes to `~/.vim`, including a symlink's destination. Do not run it against
an existing shared or cloud-synced tree before settling that tree's migration.

Use the actual Vim executable, not a shell alias for Neovim. In a new account,
run from this checkout:

```sh
cp -n home/dot_vimrc "$HOME/.vimrc"
vim
```

Then run `:VimSetup`, review its output and `:PlugStatus`, and restart Vim.
To try the entrypoint without replacing an existing vimrc, use `vim -u "$PWD/home/dot_vimrc"`.
That only selects the entrypoint; use a separate home directory for an isolated
trial. Existing personal color files are kept; empty or unreadable color assets
stop setup rather than being overwritten. A failed or empty manager download
preserves the installed manager and stops setup instead of continuing with the
old version. Downloads are staged beside their targets, so failed transfers do
not publish partial files. Plugin state is owned by vim-plug: setup does not run
`PlugUpdate` or `PlugClean`. Plugin hook failures may require vim-plug's explicit
forced-install retry after fixing the cause; repository status alone is not a
feature-health check.

Before replacing a different manager, setup saves its exact previous contents
to `~/.vim/autoload/plug.vim.old`. Identical downloads leave this backup intact;
first installation creates no backup. A backup-write failure stops replacement.
Missing or zero-byte manager files are treated as uninstalled: they are neither
sourced nor copied over an existing backup.
The backup is published before the manager, not as a two-file transaction: if
the final replacement fails, the active manager remains and `.old` may equal it.
The copy is a previous version, not a verified known-good version. There is no
automatic rollback. To restore it manually, close Vim, copy it back, and restart:

```sh
cp "$HOME/.vim/autoload/plug.vim.old" "$HOME/.vim/autoload/plug.vim"
```

The next `:VimSetup` attempts the latest upstream manager again.

Only personal color sources are pinned. The manager follows upstream `master`;
this does not guarantee compatibility with every future upstream change. Exact
plugin-version replay, editing history/caches, and external tools such as Ruff,
isort, language runtimes and other ALE executables are outside this recovery
scope. Existing Vim mappings are retained; keymap redesign is separate from
recovery. Neovim has an independent configuration.

The full suite fetches the same latest vim-plug URL once for its real-manager
checks; network or upstream compatibility failures are test failures:

```sh
python -m unittest discover -s tests/vim -v
```

Workflow and failure tests use real Vim with download/installation doubles and
can run without network access:

```sh
python tests/vim/test_recovery.py VimRecoveryTests -v
```

Neither tier installs the declared plugins or establishes their runtime compatibility.

## chezmoi placement

The repository's `.chezmoiroot` file selects `home/` as its source state. The only
managed target is `.vimrc`, from the plain, non-template `home/dot_vimrc` file.
Tests, docs and `.vim/colors` stay outside that state. The color files are authored
assets used by standalone recovery and its tests, not a runtime tree to symlink
into a home directory. Do not symlink the repository's `.vim` directory as `~/.vim`.

For this checkout, pass `--source "$PWD"` explicitly. Rehearsals must use a
temporary `HOME`, `TMPDIR`, all four `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`,
`XDG_DATA_HOME`, `XDG_STATE_HOME` paths, and a temporary `--destination`.
Changing only `--destination` does not isolate chezmoi's own state. Run `managed`
to confirm the target list, review `diff`, then use `apply` in that same isolated
environment. Apply places the vimrc only: it does not invoke `:VimSetup`, install
plugins, or manage `~/.vim`.

The optional chezmoi tests run with an executable found on `PATH` or selected by
`CHEZMOI`; otherwise they explicitly skip. They use isolated homes and exercise
the actual `managed`, `diff`, `apply` and `verify` commands, including replacing a
synthetic vimrc symlink without changing its old target or the runtime directory:

```sh
python -m unittest discover -s tests/chezmoi -v
```

Before an approved live migration, record both existing Vim link targets. If
`~/.vim` is the expected link to a shared runtime, remove only the link and create
a local directory before running `:VimSetup`. Stop on an unexpected target type;
never recursively remove the shared directory. There is no persistent chezmoi
removal rule for this generated runtime. Permanent CLI provisioning, sourceDir
binding and actual-home apply are separate from this source preparation.

To roll back that migration, preserve the new local runtime under another name
and restore both recorded links. Stop running `chezmoi apply` until deciding
whether to retry or withdraw the Vim source: restoring the links does not remove
the desired vimrc from chezmoi, and a later apply would replace it again.

## Pi themes

See [Pi PaperColor themes](pi/README.md) for installation and palette details.

## brew

```bash
brew install zsh vim neovim cmake git bazel fzf fd julia go crystal openssh pandoc nodejs ack the_silver_searcher r rstudio rbenv brave-browser visual-studio-code textmate xquartz brewsci/bio/pymol
```

## conda

[Mambaforge download](https://github.com/conda-forge/miniforge)

```bash
# general
mamba install altair plotnine black cython flake8 isort parmap pynvim pyarrow
# science
mamba install openmm mdtraj parmed oddt rdkit molvs mordred deepchem cmcrameri colorcet ambertools
mamba install -c omnia openforcefield openforcefields
# ML, cuda dependent
mamba install -c pytorch pytorch torchvision
mamba install -c pyg pytorch-scatter pytorch-sparse pytorch-cluster pytorch-spline-conv pyg
mamba install -c rapidsai cudf cuml
mamba install einops opt_einsum scikit-learn pytorch-lightning optuna
```
