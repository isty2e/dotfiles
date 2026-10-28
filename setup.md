# Setup

This guide covers bootstrap, shell settings, tools and tests. For everyday edits,
see [Editing managed configuration](docs/manifest-management.md). Vim and Neovim
have [separate](docs/vim.md) [setup guides](docs/neovim.md).

## First apply on an existing home

1. Back up affected files and link targets outside the checkout. Keep those
   backups private: old shell startup files may contain credentials.
2. Move machine settings to `~/.config/dotfiles/local.sh`. Keep credentials outside
   Git and arrange their private loading before replacing startup files. On Linux,
   use `~/.config/dotfiles/credentials.sh` with owner-only permissions; `local.sh`
   can load existing trusted private shell code on other hosts.
3. Review the intended source and existing configuration before applying it.
   In particular, keep any wanted changes made with `daem add`: the managed
   manifest may be older than `~/.config/daem/daem.toml`.

Bootstrap uses `--less-interactive --error-on-conflict` for both `apply` and
`init --apply`. Differing existing or changed targets stop it for manual review.
Unchanged repeat applies and targets that do not exist can proceed. This does not
make apply atomic: initialization and earlier placements may already have
happened. After-install actions may not have run or finished, so do not infer that
tools and plugins are ready from the presence of configuration files.
Before first initialization, bootstrap creates `~/.config` with owner-only
permissions only if it is absent. An existing directory with different permissions
still requires review; bootstrap does not silently tighten it.

The managed `.config`, `.config/daem` and `.config/dotfiles` directories use
`0700`; `.config/daem/daem.toml` uses `0600`. These are declared target modes,
not a rule that retains any stricter existing mode.

On a stop, back up affected files and link targets privately. Once chezmoi is
bound to this checkout, review and choose changes interactively:

```sh
chezmoi diff
chezmoi diff ~/.config/daem/daem.toml
chezmoi apply --less-interactive
```

If bootstrap just installed chezmoi, first add `~/.local/bin` to your shell's
`PATH`. Rerun bootstrap after resolving differences to finish pending setup.
Direct native apply without these options can overwrite an existing,
never-written file without asking; neither path creates automatic backups.

Do not bulk `re-add` before this first reviewed apply, or when a later update adds
new managed files. It can replace the new source with old live content, including
secrets. After placement, use the
[status and capture procedure](docs/manifest-management.md#capture-local-edits).

## Bootstrap a checkout

You need Git, a POSIX shell and curl with HTTPS support. Before applying to an
existing home, follow the first-apply steps above. Apply replaces managed
`.bashrc` and `.zshrc` files. If an editor uses linked settings or
a shared runtime, follow [the migration guide](docs/editor-migration.md) first.
Also review [existing binary providers](#mise-global-tools) before installing
replacement editor or tmux binaries.

```sh
git clone https://github.com/isty2e/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
sh bootstrap.sh
```

Bootstrap reuses chezmoi and mise on `PATH`. It installs missing copies in
`~/.local/bin` by downloading and running their official installers from
[get.chezmoi.io](https://get.chezmoi.io) and [mise.run](https://mise.run).
Bootstrap itself needs no Python, Node or Pixi environment and does not call
sudo, Homebrew or `chsh`. Tool backends may have their own platform requirements.
You can install chezmoi and mise yourself before running bootstrap.

On first use, `home/.chezmoi.toml.tmpl` binds chezmoi to this checkout; it does not
create another clone. Bootstrap reuses an existing configuration bound here.
If it points elsewhere, bootstrap stops. Review the reported config file and
correct its `sourceDir` before retrying. You can invoke bootstrap from another
directory.

A full apply places configuration, runs `mise install` with the managed global
TOML, and prepares the shell plugins. These steps download tools and plugins and
execute third-party installation code. The installation actions run on first
apply and when their declarations change; unchanged repeat applies skip them.

If installation fails, files already placed and tools already installed remain.
Fix the cause and rerun bootstrap, or review differences with
`chezmoi apply --less-interactive`. For non-interactive configuration-only
placement, use `chezmoi apply --exclude=scripts --less-interactive --error-on-conflict`.
Applying a single file does not necessarily run
the installation actions. Use native mise commands to repair or update tools;
chezmoi's successful-run record does not check installed-tool health.

Bootstrap changes `PATH` only in its child process. Start a new interactive shell
to load the installed settings, or expose the bootstrap executables now:

```sh
export PATH="$HOME/.local/bin:$PATH"
mise ls
```

### Repair or update shell plugins

Sheldon prepares plugins in a new directory and activates it only after
preparation succeeds. Apply leaves existing plugin checkouts unchanged. To
restore missing plugins without changing the declaration, run:

```sh
CHEZMOI_DEST_DIR="$HOME" sh "$(chezmoi source-path)/run_onchange_after_install-shell-plugins.sh.tmpl"
```

Append `--update` to that command to fetch updates in a new directory. Existing
shells continue using their previous plugin set. Old and interrupted preparations
remain under `~/.local/share/dotfiles/sheldon/generations`; the adjacent `current`
file identifies the active one. Remove an old directory only after all shells
using it have exited. Run one preparation at a time on a shared home.

## Chezmoi placement

`.chezmoiroot` selects `home/` as the source. Chezmoi removes source attributes
such as `dot_` and `private_` when constructing target paths:

| Source | Destination |
| --- | --- |
| `home/dot_bashrc`, `home/dot_zshrc` | `~/.bashrc`, `~/.zshrc` |
| `home/dot_vimrc` | `~/.vimrc` |
| `home/private_dot_config/nvim/` | `~/.config/nvim/` |
| `home/private_dot_config/helix/` | `~/.config/helix/` |
| `home/private_dot_config/zed/` | `~/.config/zed/` |
| `home/private_dot_config/mise/config.toml` | `~/.config/mise/config.toml` |
| `home/private_dot_config/starship.toml` | `~/.config/starship.toml` |
| `home/pixi-env/base/pixi.toml` | `~/pixi-env/base/pixi.toml` |

`private_dot_config` gives `.config` mode `0700`. Each editor keeps its own loader.
Tests, docs, Lua tooling and the repository's `.vim/colors` assets stay outside
the managed home tree. Use [Vim setup](docs/vim.md) to acquire those color assets;
do not link the repository's `.vim` directory as your runtime.

Apply places configuration, not editor plugins, language servers, Tree-sitter
parsers or the Pixi environment. It leaves `~/.vim`, Neovim data/caches and Helix's
generated `runtime/grammars` tree unmanaged. For an existing home or an isolated
rehearsal, see [Editor migration](docs/editor-migration.md).

## Shell settings

### Machine settings and credentials

Bash and Zsh read `~/.config/dotfiles/local.sh` before tool activation. Put
machine-specific paths and cluster settings there. For example, set
`BREW_LOCATION` to the Homebrew executable if startup cannot find it in `PATH` or
a standard location. This local file is outside Git.

Keep machine locations independent of OS and CPU selection. Export
`DK_VAULT_PATH` from `local.sh` with this machine's existing knowledge-vault path;
do not infer it from Linux, macOS or a CPU architecture. Shared policy stays in
the common shell configuration, while native platform/package conditions select
OS-specific behavior and supported binaries. Machine inputs load before those
initializers so they can select existing tools and data locations.

On Linux, startup also reads `~/.config/dotfiles/credentials.sh` and exports its
assignments. The file must belong to the current user and have no group or world
permissions. Startup skips an insecure or unreadable file with a warning. Keep
credentials outside Git and restrict the file before use. Both files contain
shell code: source only trusted content.

### Bash, Zsh and completion

An interactive Linux SSH Bash session replaces itself with Zsh when available.
Set `DOTFILES_KEEP_BASH=1` before starting Bash to keep it. Non-interactive
commands are unchanged. The account's login shell remains Bash, and its login
profile must source `.bashrc`; this repository does not replace that profile.

The new Zsh exports its executable path as `SHELL` for child programs. An existing
tmux server keeps its configured default shell. Programs started on another node
need that Zsh executable at the same path.

Zsh loads prepared plugins without downloading them. Bash needs version 4.2 or
newer for bash-completion and fuzzy Tab completion. Fuzzy Tab also needs `fzf`
and `tac`; on macOS it needs an awk with GNU awk's interactive option. If a
dependency is missing, startup leaves the available native completion in place.
Bash's `extract` command uses the prepared Zsh plugin and needs Zsh.

Full apply installs the declared Zstandard command-line tools. Transfer aliases
need rsync with `--info=progress2`, which the macOS system version may lack.
`rsmv` removes transferred source files; `rssync` uses `--delete` on the
destination. Review the command before using either on data. `cpv` defaults to
`/home/$USER/rsync` for backups. Override `DOTFILES_RSYNC_BACKUP_DIR` in `local.sh`
if needed; create the chosen backup directory yourself.

### History, prompt and environments

Zsh uses shared history. Bash adds prompt-by-prompt history sharing on macOS,
but keeps native persistence on Linux. These settings can still lose concurrent
history on NFS: Bash can truncate to `HISTFILESIZE`, and Zsh rewrites shared
history periodically. On macOS Bash 3.2, `history -a` may not append if a session
starts with an empty or absent history file. The fzf Bash history picker's
Shift-Delete action can also rewrite history.

Startup uses installed mise tools and activates an installed Pixi base unless
another environment is active. Mise's normal precedence can still change which
executable a command selects. Pixi activation uses `shell-hook --as-is`, without
installing packages or updating the lockfile. An existing `~/pixi_envs/base`
environment takes precedence over `~/pixi-env/base`. Set
`DOTFILES_PIXI_BASE_MANIFEST` or `PIXI_ENVS_HOME` in `local.sh` to select another
base without moving it. See [manifest paths and local state](docs/manifest-management.md#manifests-and-local-state).

Starship uses its installed executable. If it is unavailable, startup keeps the
existing prompt. Logins, environment installation and editor plugin setup remain
explicit operations.

Both shells export `PI_CLIPBOARD_OSC52=1` for Pi's OSC52 clipboard handling.

## Mise global tools

The full tool list is in `home/private_dot_config/mise/config.toml`. Node uses
`lts`; other tool versions use `latest`. Plain names use mise's registry defaults.
Pi and zvec-grep use explicit npm backends with the declared Node runtime.
Chezmoi and mise itself remain bootstrap tools outside this manifest.

Rust uses rustup-backed management and reads `rust-toolchain.toml` for project
selection. Mise 2026.10.12 does not recognize the extensionless `rust-toolchain`
file; check legacy projects before changing their provider. Project mise files
keep their normal precedence. Ruby may need a source build and preinstalled
build dependencies when no binary is available, including on no-admin hosts.

pre-commit uses the PyPI backend with uv and a private Python 3.13 interpreter.
It does not depend on Pixi or provide a global Python command. Pixi retains its
own pre-commit dependency. Inspect or reinstall hooks that refer to an old
interpreter when changing providers. uv remains a CLI tool; scientific libraries
and project Python environments stay with their respective environment managers.

The gdu GitHub adapter installs `gdu-go`, avoiding a collision with GNU coreutils'
`gdu`. Kata uses its existing installer and update procedure, which also manages
its daemon. It is not a mise tool in this configuration.

Installing new binaries leaves other providers in place. Before switching an
editor, check its runtime, plugins and grammars. Plan an existing tmux server's
session lifecycle separately from installing its binary. Mise retains its native
version-cleanup behavior. Shell activation, logins, search indexes and model
caches are separate from tool installation.

## Pixi base environment

`home/pixi-env/base/pixi.toml` requires Pixi 0.81 or newer. It supports macOS ARM
with a macOS 14 baseline and Linux x86-64 with CUDA 12.8. The Linux target is not
a CPU-only profile. Both use the `default` environment and its existing prefix.

Target tables hold the platform-specific additions. The Mac CDPKit bound remains
until compatibility has been checked. Linux PyTorch uses the cu128 index; other
packages use the normal PyPI index. Supply access to Git dependencies outside
this repository.

Review the manifest diff before replacing an existing file. Apply copies the
declaration; install the environment separately:

```sh
pixi install --manifest-path "$HOME/pixi-env/base/pixi.toml"
```

Pixi can change installed packages when it reconciles the declaration. Keep
`.pixi/` and `pixi.lock` local; Git and chezmoi exclude them. Capture TOML edits
through [the normal editing workflow](docs/manifest-management.md).

## Commit checks

`.pre-commit-config.yaml` pins the official Gitleaks hook. With the declared Go
and pre-commit tools available, install it from the checkout:

```sh
pre-commit install --install-hooks
```

The first installation downloads and builds Gitleaks in pre-commit's user cache.
It needs no administrator privileges. Later commits reuse that environment.
The hook checks staged changes and redacts detected secrets in its output.
A finding or an unavailable scanner stops the commit; it does not remove the
suspected value for you.

Installation is separate from chezmoi apply. Linked worktrees share the installed
Git hook, but each checked-out revision must contain `.pre-commit-config.yaml`.
A revision without that file cannot commit until the configuration is present;
do not enable missing-config skipping to work around this.

Default rules cannot recognize every secret, and Git allows hooks to be bypassed.
Keep credentials outside Git and review staged changes. If a real false positive
needs an exception, scope it narrowly rather than excluding an entire shell
configuration. CI after a public push is not a pre-publication barrier.

## Tests

The offline runner needs Python 3.11+, the packages in
`tests/keymaps/requirements.txt`, Bash, Zsh, Vim and Git:

```sh
sh tests/run.sh
```

Set `PYTHON` to choose the interpreter. Chezmoi tests skip if chezmoi is missing.
The runner detects mise and Pixi; override `MISE`, `PIXI` or `CHEZMOI` with actual
executable paths, not shell functions or version-manager shims. Pixi must be
0.81 or newer. Interactive checks use `expect` when available; the tmux test skips
without tmux.

Bootstrap tests use offline installer and executable doubles. Native chezmoi
tests exercise source binding, apply and preservation with isolated homes, but
still use a mise double. Native mise checks read metadata and project Rust
selection without installation. Native Pixi checks read manifest metadata
without installing packages. These checks skip when their tools are unavailable.

Network-backed Vim recovery and plugin-loaded editor checks run separately:
see [Vim tests](docs/vim.md#tests) and [Neovim tests](docs/neovim.md#verify-without-deployment).
The offline runner does not imply that these optional checks ran.

## Slurm commands

Chezmoi places `sbatchall` and `slurm-cancel` in `~/.local/bin`. They use Slurm on
`PATH` only when invoked.

`sbatchall` submits `slurm_1.sh`, `slurm_2.sh`, and so on from the current
directory, pausing one second after each success. It stops at the first missing
file or failed submission. Earlier jobs stay submitted; rerunning starts at the
first file and can create duplicates.

`slurm-cancel` cancels the current user's queued jobs. `-n NAME` selects a job
name. `-r START END` sends every ID in that inclusive range directly to Slurm,
without a current-user filter; Slurm checks authorization. A failed queue query
makes no cancellation attempts. Test the helpers without real jobs using
`sh tests/slurm/test_helpers.sh`.

## Vim recovery

See [Vim setup and recovery](docs/vim.md). Use the
[migration guide](docs/editor-migration.md) before replacing existing links or a
shared runtime.

## Neovim

See [Neovim configuration](docs/neovim.md) for installation, plugins, language
tools and tests. Preserve an existing configuration Git checkout before applying;
the [migration guide](docs/editor-migration.md#neovim) explains how.

## Pi themes

See [Pi PaperColor themes](pi/README.md) for optional installation and palettes.
