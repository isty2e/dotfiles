# Settings

See [Colemak keymap policy](docs/keymaps.md). Execution and migration are tracked in Kata.

## Bootstrap a checkout

Start with Git, a POSIX shell and HTTPS-capable curl. Existing homes need a
configuration diff and backup first; follow the editor handoff instructions below
before replacing linked configuration. Bootstrap does not migrate editor runtimes.

```sh
git clone https://github.com/isty2e/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
sh bootstrap.sh
```

Bootstrap reuses chezmoi and mise found on `PATH`, including existing package-manager
installations. Missing tools are installed into `~/.local/bin` by downloading and
executing their official installers from [get.chezmoi.io](https://get.chezmoi.io)
and [mise.run](https://mise.run). It does not invoke sudo, Homebrew or `chsh`.
For manual provisioning, install those two executables using their official
instructions, then rerun bootstrap; it will skip their acquisition. No Python,
Node or Pixi environment is needed to run bootstrap itself.

On first initialization, `home/.chezmoi.toml.tmpl` records this checkout as
chezmoi's `sourceDir`; there is no second source clone. An existing configuration
bound to this checkout is reused without regenerating its settings. If it points
elsewhere, bootstrap stops: review the reported configuration file and reconcile
`sourceDir` explicitly before retrying. Bootstrap can run from outside the checkout.

A full chezmoi apply places the authored configuration, then runs `mise install`
using the managed global TOML. This can download tools and execute third-party
installation code. The native `run_onchange_after` action runs on first application
and when its rendered contents change; the mise TOML fingerprint is part of those
contents. Unchanged repeat applies skip the action. Successful run state is not
installed-tool health: use native mise commands for repair or updates.

After an installation failure, files already applied and completed native tool
installs are not rolled back. Fix the reported cause and rerun bootstrap or a full
`chezmoi apply`. For configuration-only placement, use `chezmoi apply --exclude=scripts`.
Applying an individual file does not promise to run the installation action.

Bootstrap changes `PATH` only in its child process. Shell configuration is not
currently deployed by this source. Make the bootstrap executables available in
your current shell, then configure [mise activation](https://mise.jdx.dev/getting-started.html)
for the shell you use; opening another terminal alone does not add that integration:

```sh
export PATH="$HOME/.local/bin:$PATH"
mise ls
```

Logins, credentials and login-shell selection remain separate. Pixi base environment
installation and `:VimSetup`/`:NvimSetup` remain explicit operations described below.

The bootstrap tests use offline installer/executable doubles. Native chezmoi
integration additionally checks source binding and configuration preservation when
chezmoi and Git are available; it still uses a mise double, not real tool acquisition:

```sh
python -m unittest discover -s tests/bootstrap -v
```

## Legacy shell notes

These historical shell files are not applied by bootstrap or chezmoi. Review them
separately rather than treating these commands as the current environment restore path.

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
scope. Fixed Colemak mappings follow [the keymap policy](docs/keymaps.md), while
recovery and deployment remain separate. Neovim has an independent configuration.

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

The native keymap integration suite needs actual Vim and an already installed
vim-plug/NERDTree runtime. Run it in a terminal after plugin startup:

```sh
sh tests/keymaps/run-vim.sh
```

`VIM_TEST_BINARY` can select an actual Vim executable, and `VIM_TEST_RUNTIME` can
select an existing runtime directory. The runner uses a temporary home and XDG
state, borrows cached plugin code, and does not run `VimSetup`. Missing prerequisites
or a non-terminal invocation produce exit code 77. Normal terminal Vim lets startup
and UI commands execute in their native context; Ex-only runs are not treated as
full-profile coverage. Core movement, native
operators, literal input, window cycles and NERDTree commands are tested by effects.

## chezmoi placement

The repository's `.chezmoiroot` file selects `home/` as its source state.
`private_dot_config/` keeps the native `.config` directory private (`0700`);
the `private_` prefix is a chezmoi attribute, not part of the target path. It manages
`.vimrc` from plain `home/dot_vimrc` and the Neovim configuration files from
`home/private_dot_config/nvim/` at `.config/nvim/`. Helix configuration, language settings
and themes come from `home/private_dot_config/helix/` at `.config/helix/`. Zed settings
and keymaps come from `home/private_dot_config/zed/` at `.config/zed/`. These editors keep
separate native loaders; sharing a Git repository does not make one depend on
another.
Tests, docs, Lua tooling and `.vim/colors` stay outside that state. The color files are authored
assets used by standalone recovery and its tests, not a runtime tree to symlink
into a home directory. Do not symlink the repository's `.vim` directory as `~/.vim`.

For this checkout, pass `--source "$PWD"` explicitly. Rehearsals must use a
temporary `HOME`, `TMPDIR`, all four `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`,
`XDG_DATA_HOME`, `XDG_STATE_HOME` paths, and a temporary `--destination`.
Changing only `--destination` does not isolate chezmoi's own state. Run `managed`
to confirm the target list, review `diff`, then use `apply` in that same isolated
environment. Exclude scripts for a placement-only rehearsal; a full apply can install
mise tools as described above. It does not invoke `:VimSetup`/`:NvimSetup`, install
editor plugins/language servers/parsers, or manage `~/.vim`, Neovim data/caches
or Helix's generated `runtime/grammars` tree.
The Pixi base manifest is also placed as described below; its environment is not
installed by apply.

Zed's source contains non-secret UI, language and provider preferences, not
credentials, sessions or extension state. Existing keymap rules and settings
values are preserved; placement does not switch language providers. Fonts, theme
extensions and language tools are separate prerequisites for their corresponding
features, and account login remains native to Zed. Stop Zed before replacing its
linked keymap or settings, back up both files, and review their diff before applying.

For a linked Helix configuration directory, preserve the original link and local
runtime before replacing the link with a regular directory. Keep existing
`runtime/grammars`, including its source cache, under the local `.config/helix/`;
do not copy it into the chezmoi source tree or add a persistent removal rule.
Stop Helix for the handoff so an existing process cannot retain obsolete runtime
paths. After placement, ordinary apply preserves that unmanaged runtime. Rollback
must preserve newer configuration, restore runtime custody and the original link,
and select the matching source checkout before applying again.

The optional chezmoi tests run with an executable found on `PATH` or selected by
`CHEZMOI`; otherwise they explicitly skip. They use isolated homes and exercise
the actual `managed`, `diff`, `apply` and `verify` commands, including replacing
synthetic Vim/Neovim entrypoint links, a linked Helix directory and a Zed keymap
link without changing their former sources, unmanaged runtime/editor state or
repository metadata:

```sh
python -m unittest discover -s tests/chezmoi -v
```

Before an approved live migration, record both existing Vim link targets. If
`~/.vim` is the expected link to a shared runtime, remove only the link and create
a local directory before running `:VimSetup`. Stop on an unexpected target type;
never recursively remove the shared directory. There is no persistent chezmoi
removal rule for this generated runtime. The fresh-machine bootstrap is not a
replacement for this existing-home migration or its runtime handoff.

To roll back that migration, preserve the new local runtime under another name
and restore both recorded links. Stop running `chezmoi apply` until deciding
whether to retry or withdraw the Vim source: restoring the links does not remove
the desired vimrc from chezmoi, and a later apply would replace it again.

## Neovim

See [Neovim configuration](docs/neovim.md) for selected plugins, language tools,
native keymap ownership and installation. The runtime source is
`home/private_dot_config/nvim/`; `tests/nvim/` and this repository's Lua tooling are not
deployed. The native integration runner uses an existing plugin cache without
installing dependencies:

```sh
sh tests/nvim/run-keymaps.sh
```

Before actual-home adoption, preserve an existing `~/.config/nvim` Git working
tree outside the target path. Source consolidation leaves that repository and its
history untouched and does not authorize applying over it or deleting its metadata.

## Pi themes

See [Pi PaperColor themes](pi/README.md) for installation and palette details.

## Mise global tools

`home/private_dot_config/mise/config.toml` is the plain source for
`~/.config/mise/config.toml`. Its single native `[tools]` table is grouped with
comment headings and blank lines: runtimes/environments, agent/terminal tools,
repository search, delivery/tasks and JavaScript/TypeScript quality. These are
editing groups, not nested tool namespaces or separate installation profiles.

Node uses the `lts` selector; other listed tools use `latest`. CodeGraph and
zvec-grep use explicit npm backend identifiers; their commands are `codegraph`
and `zg`. Node is declared for the npm tools' runtime requirements. Project-scoped
mise declarations retain their normal precedence over these global defaults.

Chezmoi places the declaration and its after-action invokes native mise installation
as described in the bootstrap section. The action explicitly selects the projected
global TOML, including in isolated destinations or with a custom XDG configuration
directory; native mise project/default precedence still applies. This file does not
configure shell activation, authentication, search indexes or model caches.
Python environment packages remain in the Pixi manifest
rather than being duplicated here. Existing executable providers are not removed;
any provider retirement is separate. Mise retains
its native version-cleanup behavior.

Set `MISE` to the actual mise executable to run the optional native metadata
check. It reads the copied declaration with isolated home, config, data, cache
and state paths; otherwise it skips explicitly:

```sh
python -m unittest discover -s tests/mise -v
```

## Pixi base environment

`home/pixi-env/base/pixi.toml` is the plain source for
`~/pixi-env/base/pixi.toml`. It requires Pixi 0.81 or newer, provisioned separately.
Common requests are declared once; native target tables select the Mac ARM
configuration with a macOS 14 baseline or the Linux x86-64 configuration with
CUDA 12.8. This Linux target is not a generic CPU-only Linux profile. Both use the
native `default` environment, without a new environment name or prefix.

Target-specific additions reflect selected usage, not universal OS restrictions.
The Mac CDPKit bound remains in place pending compatibility validation. Linux
PyTorch uses the cu128 index directly; other requests keep the normal PyPI index.
Access to Git-sourced dependencies is supplied outside this repository.

Review the chezmoi diff before replacing an existing manifest. Apply places only
the declaration; subsequent Pixi operations can reconcile the environment from
it. To install explicitly after placement:

```sh
pixi install --manifest-path "$HOME/pixi-env/base/pixi.toml"
```

The `.pixi/` environment and `pixi.lock` are local generated state, excluded from
Git and chezmoi source; they are not versioned or deployed.
Use normal Pixi commands to change declarations, then review and re-add the TOML
to chezmoi source; do not add the generated environment directory.

The optional native parser check requires `PIXI` to be set to an absolute Pixi
0.81+ executable path, not a version-manager shim. Otherwise it skips explicitly.
It uses an isolated home and reads metadata without installing packages:

```sh
python -m unittest discover -s tests/pixi -v
```

## brew

```bash
brew install zsh vim neovim cmake git bazel fzf fd julia go crystal openssh pandoc nodejs ack the_silver_searcher r rstudio rbenv brave-browser visual-studio-code textmate xquartz brewsci/bio/pymol
```

## Legacy conda notes

These historical commands are not part of the Pixi base setup above.

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
