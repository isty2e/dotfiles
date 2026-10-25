# Settings

## dotfiles

```bash
git clone https://github.com/tarjoilija/zgen
ln -s dotfiles/.zshrc ~/.zshrc
ln -s dotfiles/.zshrc_linux ~/.zshrc
```

## Vim recovery

The `.vimrc` is the recovery entrypoint; an existing `.vim` directory is not
required. It declares vim-plug, plugins, three personal colorschemes, and the
HTML/Python/Ruby/Rust/Swift indentation settings. This vimrc does not start
downloads or installation during ordinary startup. A missing manager or plugin
directory produces a warning. If codedark is unavailable, Vim uses the default
colorscheme while keeping core editing available.

Recovery requires Vim with `+eval`, Git, curl with HTTPS support, and network
access to GitHub and plugin download hosts. It needs no administrator rights.
Every `:VimSetup` fetches the latest vim-plug from its official `master` branch
and replaces the installed manager, even when one already exists. It acquires
missing personal color files into `~/.vim`, reloads the refreshed manager, then
runs vim-plug's synchronous installation under `~/.vim/plugged`. This executes
third-party plugin code and the fzf binary installer. The fzf hook uses `--bin`,
not shell integration; setup does not edit shell startup files.

In a new account, run from this checkout:

```sh
cp -n .vimrc "$HOME/.vimrc"
vim
```

Then run `:VimSetup`, review its output and `:PlugStatus`, and restart Vim. To try
the entrypoint without replacing an existing vimrc, use `vim -u "$PWD/.vimrc"`.
Setup still writes to `~/.vim`; use a separate home directory for an isolated
trial. Existing personal color files are kept; empty or unreadable color assets
stop setup rather than being overwritten. A failed or empty manager download
preserves the installed manager and stops setup instead of continuing with the
old version. Downloads are staged beside their targets, so failed transfers do
not publish partial files. Plugin state is owned by vim-plug: setup does not run
`PlugUpdate` or `PlugClean`. Plugin hook failures may require vim-plug's explicit
forced-install retry after fixing the cause; repository status alone is not a
feature-health check.

Only personal color sources are pinned. The manager follows upstream `master`;
this does not guarantee compatibility with every future upstream change. Exact
plugin-version replay, editing history/caches, and external tools such as Ruff,
isort, language runtimes and other ALE executables are outside this recovery scope. The current
legacy Vim mappings are retained; they have not yet been migrated to the shared
Colemak policy. Neovim has an independent configuration.

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
