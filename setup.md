# Setup

Git, a POSIX shell and HTTPS-capable curl are required. Bootstrap can acquire
chezmoi and mise through their official installers in `~/.local/bin`; it does not
require administrator privileges. Tool installation uses the network and runs
third-party installers and builds.

## First apply on an existing home

Back up startup files, managed settings, symlink targets and native workspaces to
a private location outside Git. Inspect `chezmoi diff` before applying. Keep
machine values and secrets in private device files, not the shared sources:

- `~/.config/shell/device/local.sh`: machine-specific paths and shell settings.
- `~/.config/shell/device/credentials.sh`: trusted shell code containing
  credentials. Only readable, user-owned files with no group/other permissions
  are loaded; use 0600.

The managed `.config` and `.config/shell` directories use 0700. This can remove
access previously granted to other users; review shared-home requirements first.
Bootstrap uses conflict protection and stops rather than silently replacing
existing startup files or native workspace directories. Earlier entries may have
been applied before a conflict. There is no automatic backup or rollback.

### Native workspace migration

The source checkout must remain at a stable location. Mise and daem now use
directory bindings; Pixi uses an actual workspace in the checkout. Do not force
chezmoi to replace an existing native workspace directory: it can contain valuable
local edits, locks and daem ownership state.

For daem, first reconcile the live manifest with `workspaces/daem/daem.toml`,
privately back up the **whole** current directory, and preserve its lock and
`.daem/` contents in the new workspace before replacing the old directory with
the reviewed binding. Keep the workspace 0700 and manifest 0600. Use native
`daem apply --dry-run` afterwards; stop on unexpected adoption, deletion or
ownership changes. Do not reset state or use forced adoption to complete a move.

Older source checkouts can also contain ignored state under
`home/private_dot_config/private_daem/` or `home/pixi-env/base/`. Git does not move
those files with the declarations. Privately preserve them and reconcile them
with the corresponding new workspace before applying. Retired source directories
can conflict with the new directory bindings; remove only empty retired
directories after their contents are safely preserved, never clean them forcibly.

For mise, reconcile the global declaration and preserve any other local files
before replacing its config directory. Existing installed runtimes stay in
mise's data directory. No automatic migration script is provided.

For Pixi, build a separate environment with the new workspace manifest, verify
it, then switch new shell activation. **Do not move a live `.pixi` prefix.** Keep
the old environment and running processes intact until cleanup is explicitly
chosen. `DOTFILES_PIXI_BASE_MANIFEST` in local settings can continue selecting
the old manifest while preparing the new one.

Removing the tracked Neovim lock does not delete a live `lazy-lock.json`. It is
unmanaged and stays local. Preserve it if native restore on that machine matters.
After adopting the new editing workflow, retire any old installed
`~/.local/bin/dotfiles-capture` alias and `dotfiles_capture.py` copy explicitly;
removing them from source does not remove an existing installed command.

## Bootstrap a checkout

```sh
git clone https://github.com/isty2e/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
sh bootstrap.sh
```

Bootstrap binds chezmoi to this checkout, deploys settings with
`--less-interactive --error-on-conflict`, then explicitly runs mise installation
and shell-plugin preparation. Repeating bootstrap repeats those explicit setup
operations; ordinary apply never installs them. Pixi, daem resources, editor
plugins, account logins and changes to the login shell remain manual.

After a placement conflict: back up the affected files and targets, inspect
`chezmoi diff`, choose changes with `chezmoi apply --less-interactive`, then rerun
bootstrap to finish installation. A failed installation leaves configuration
placed and may leave some packages installed; retry bootstrap after addressing
the native error. It does not undo completed steps.

## Chezmoi placement

`home/` contains ordinary configuration. Files are copied, not linked, except
for the mise and daem **directory** bindings. A small configuration-only hook
protects the actual daem workspace permissions before binding it. Review existing
editor links and shared runtime directories using the
[editor migration guide](docs/editor-migration.md).

Edit managed settings in their source, not the deployed copy. The
[editing guide](docs/manifest-management.md) defines declaration ownership,
source editing, updates, drift handling and local-state exclusions.

## Shell settings

Interactive Bash and Zsh use the following ownership boundaries under
`~/.config/shell/`. Noninteractive shells do not initialize this profile.

| Location | Responsibility |
| --- | --- |
| `platforms/init.sh`, `platforms/macos.sh`, `platforms/linux.sh` | OS selection and defaults: listing flags and SDK/locale |
| `device/local.sh` (unmanaged) | This device's paths and overrides; loaded after OS defaults, before tools |
| `preferences.sh` | Shared editor, clipboard, aliases and command preferences |
| `integrations/` | Optional Homebrew, mise/Pixi, Slurm and prompt integration on either OS |
| `bash/`, `zsh/` | Shell-native handoff, completion, history and plugin mechanics |

The corresponding source is `home/private_dot_config/private_shell/`.
The `private_` attributes retain the owner-only directory permissions; they are
not part of the deployed path names.

The entrypoints show these stages explicitly. Ordinary Zsh options live directly
in `.zshrc`. Device settings can override platform defaults and shared editor
choices. For example, put `BREW_LOCATION`, `DOTFILES_PIXI_BASE_MANIFEST`,
`DOTFILES_RSYNC_BACKUP_DIR` or `DK_VAULT_PATH` in `device/local.sh` rather than
creating a hostname profile in Git.

Zsh uses case-insensitive native completion followed by its `_approximate`
completer (`max-errors=2`). fzf-tab selects from those candidates; its menu uses
plain description groups and `LS_COLORS` filename styling, not a second native selection
menu. Autosuggestions default to gray (`fg=#808080`); standalone fzf uses
`fd --type f`. These defaults precede device settings, so `device/local.sh` can
override the native completion styles and plugin variables. Command-name
correction confirmation remains disabled; Bash matching policy is unchanged.

History defaults are independent of OS and precede device settings. Bash uses
`HISTSIZE=1000` and `HISTFILESIZE=2000`; Zsh uses `HISTSIZE=4096` and
`SAVEHIST=4096`. Set the native variables, `HISTFILE`, or Zsh options in
`device/local.sh` to override them; later initialization does not reset them.
Bash retains native exit-time history persistence. Additional prompt-time
append/read synchronization is off by default; set
`DOTFILES_BASH_HISTORY_SYNC=1` on devices where shared interactive history is
wanted. No OS-based NFS assumption is made. The prompt hook uses `history -a`
and `history -n`, not `history -w`, but Bash can still trim its history file
according to `HISTFILESIZE`. Zsh's default `SHARE_HISTORY` also periodically
rewrites its file. Sharing is best effort, not a loss-free concurrent log on NFS;
the isolated local tests do not establish behavior on the cluster filesystem.
For an NFS-backed Zsh history, native `HIST_FCNTL_LOCK` is an available device
option; the [Zsh documentation](https://zsh.sourceforge.io/Doc/Release/Options.html#History)
specifically discusses NFS corruption avoidance, without establishing a guarantee
for every server/mount configuration. A local `HISTFILE` is another option when
sharing across different hosts is not required.

Create `~/.config/shell/device/` privately, with mode 0700. Its
`local.sh` and `credentials.sh` are the only device-file locations loaded by the
profile. Missing files are optional; no alternate path is searched. These files
are trusted shell code and must remain outside Git.

Private `device/credentials.sh` is an opt-in path on either OS. It must be
user-owned, readable and have no group/other access, normally 0600. An unsafe
file is skipped with a warning. Credential loading preserves the caller's export
setting.

Zsh options include `autocd`; Colemak bindings are intentional. Bash retains its
own history and completion behavior. Homebrew availability and Slurm commands do
not identify a device as a particular operating system or cluster.

SSH interactive Bash hands off to an available Zsh unless `DOTFILES_KEEP_BASH=1`
or a handoff guard is active. This happens before profile/device code to avoid
executing it twice; pass a handoff guard in the invoking environment, not only in
the device file.
Starship supplies the prompt when installed. Existing tmux sessions keep their
current environments; new shells read the deployed settings.

### History, prompt and environments

Mise activation reuses installed tools and disables automatic installation.
The default Pixi manifest is rendered from this checkout's
`workspaces/pixi-base/pixi.toml`; no runtime source lookup is needed. Explicit
`DOTFILES_PIXI_BASE_MANIFEST` and `PIXI_ENVS_HOME` overrides take precedence.
An inherited Pixi project, Conda environment or virtualenv is not replaced.
Without an already installed default Pixi environment, startup skips activation.
If no manifest is selected, old `~/pixi-env` or `~/pixi_envs` directories are not
searched automatically. The shared `cpv` alias defaults its backup directory to
`$HOME/rsync`; `DOTFILES_RSYNC_BACKUP_DIR` selects a device-specific alternative.

### Repair or update shell plugins

From the operational checkout:

```sh
sh scripts/install-shell-plugins.sh
# Intentionally resolve updated plugin revisions:
sh scripts/install-shell-plugins.sh --update
```

The installer reads `workspaces/sheldon/plugins.toml`, prepares a new generation
under `~/.local/share/dotfiles/sheldon`, and publishes it only after success.
Failures leave the current generation intact; previous generations and legacy
plugin checkouts are retained. Shell startup only loads prepared plugins.
Zsh loads fzf-tab only after the fzf initialization hook succeeds. Missing or
failed fzf initialization skips that selector without skipping the other plugins.

## Mise global tools

`~/.config/mise` links to `workspaces/mise`. Use normal `mise use --global …`
or edit its `config.toml` and run `mise install`. Tool requests retain their
existing version policies; a repository rollback is not a package rollback.

## Pixi base environment

```sh
cd "$HOME/dotfiles/workspaces/pixi-base"
pixi install
```

Use native `pixi add`, `pixi remove` and `pixi update` here. Only the manifest is
shared. `.pixi/` and `pixi.lock` remain local. Linux's CUDA requirement still
requires a suitable host; a virtual CUDA override is not evidence of a GPU.
Minimal Linux images may need runtime system libraries such as libXrender and
libXext for chemistry/image operations. Do not infer macOS or cluster readiness
from an isolated Linux installation alone.

## Agent environment

`~/.config/daem` links to `workspaces/daem`. Native commands use this default
location and directly edit the tracked manifest. Use `daem lock`, review
`daem apply --dry-run`, then apply explicitly. Generated lock/state/cache files
are local; preserve them when moving or backing up the workspace. Private source
access and authenticated integrations require their normal credentials.

## Commit checks

Install the configured pre-commit hook with `pre-commit install`. Gitleaks checks
committed content; it does not make a private file safe to publish. Review diffs
and keep credentials out of declarations.

## Tests

Use Python 3.11+, chezmoi, Git, Bash, Zsh, Vim and Neovim. Expect and tmux enable
session/handoff checks; the macOS tests can also use Homebrew Bash. Install Python
test dependencies from `tests/keymaps/requirements.txt`.

```sh
sh tests/run.sh
```

Offline fixtures isolate HOME and use installation doubles. Native mise and
Pixi declaration checks use available binaries or the `MISE` and `PIXI`
overrides; missing optional tools are reported as skips. Network-backed editor
acquisition and plugin-loaded checks are separate. See [Vim](docs/vim.md),
[Neovim](docs/neovim.md), and [keymap checks](docs/keymaps.md) for their commands.
CI's pinned chezmoi version is a test input, not an exact-version runtime gate.

## Slurm commands

`sbatchall` and `slurm-cancel` are installed under `~/.local/bin`. Inspect command
help and selected jobs before cancellation. Their tests use command doubles;
they do not establish scheduler behavior on a particular cluster.

## Vim recovery

See [Vim setup and recovery](docs/vim.md). Startup does not install vim-plug.

## Neovim

See [Neovim](docs/neovim.md). Run `:NvimSetup` explicitly; local lockfiles are not
shared. Language servers and parsers remain separately installed tools.

## Pi themes

See [manual theme installation](pi/README.md#install). Agent environment deployment
and optional theme selection are separate operations.
