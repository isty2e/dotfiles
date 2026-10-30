# Setup

Install current [mise](https://mise.jdx.dev/getting-started.html), Git, a POSIX
shell and HTTPS-capable curl before using this checkout. Mise must provide native
bootstrap, dotfile groups and local configuration includes; no exact-patch
allowlist is imposed. Tool installation uses the network and runs third-party
installers and builds. This configuration does not change accounts, login shells
or system packages.

## First apply on an existing home

This layout is no longer a chezmoi source. Do not run its apply/update commands
against this checkout. Retire old source bindings and automation as part of the
handoff, preserving their state for a deliberate rollback rather than deleting it.

Back up startup files, managed settings, symlink targets and native workspaces to
a private location outside Git. Inspect `mise dot diff` from the intended checkout.
Keep machine values and secrets in private device files, not the shared sources:

- `~/.config/shell/device/local.sh`: machine-specific paths and shell settings.
- `~/.config/shell/device/credentials.sh`: trusted shell code containing
  credentials. Only readable, user-owned files with no group/other permissions
  are loaded; use 0600.

Ordinary configuration uses file links. Existing regular files conflict even when
their bytes match, so reconcile and move only reviewed files aside before the
first apply. Mise can repoint existing links without `--force`; inspect their
destinations as well as their contents. Do not force-adopt an existing home or
bulk-import private startup files. Existing destination-directory permissions are
left intact; create private device directories with 0700 and credentials with
0600. Earlier entries can remain applied after a failure; there is no automatic
backup or whole-operation rollback.

### Native workspace migration

The source checkout must remain at a stable location. Mise and daem now use
directory bindings; Pixi uses an actual workspace in the checkout. Do not force
mise to replace an existing native workspace directory: it can contain valuable
local edits, locks and daem ownership state.

For daem, first reconcile the live manifest with `workspaces/daem/daem.toml`,
privately back up the **whole** current directory, and preserve its lock and
`.daem/` contents in the new workspace before replacing the old directory with
the reviewed binding. Keep the workspace 0700 and manifest 0600. Use native
`daem apply --dry-run` afterwards; stop on unexpected adoption, deletion or
ownership changes. Do not reset state or use forced adoption to complete a move.

Git does not move ignored local state when declarations move. Preserve any state
from an older checkout layout and reconcile it with the corresponding workspace
before adoption; do not remove old directories until their contents are safe.

For mise, reconcile existing tools with `workspaces/mise/conf.d/tools.toml` and
settings with `workspaces/mise/config.toml`. Preserve other local files before
replacing the config directory. Installed runtimes stay in mise's data directory.
No automatic migration script is provided.

For Pixi, build a separate environment with the new workspace manifest, verify
it, then switch new shell activation. **Do not move a live `.pixi` prefix.** Keep
the old environment and running processes intact until cleanup is explicitly
chosen. `DOTFILES_PIXI_BASE_MANIFEST` in local settings can continue selecting
the old manifest while preparing the new one.

Neovim's live `lazy-lock.json` is unmanaged and stays local. Preserve it if native
restore on that machine matters.

## Bootstrap a checkout

```sh
git clone https://github.com/isty2e/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
mise trust
mise bootstrap
```

Native bootstrap links settings, applies the optional preload, installs the
shared tool declarations and then prepares shell plugins. Repeating it repeats
these preparation operations. Pixi environments, daem resources, editor plugins,
account logins and changes to the login shell remain separate actions.

After a conflict, preserve the affected files and link destinations, reconcile
their contents, then rerun the native command. A failed installation can leave
configuration linked and some tools installed; retry after addressing the error.
Completed steps are not undone.

## Mise deployment

`config/` contains native settings, deployed as individual links by application
groups. Mise and daem retain **directory** bindings for native editing. A
pre-dotfiles hook protects the daem workspace before publishing its link.
Review existing editor links and shared runtime directories using the
[editor migration guide](docs/editor-migration.md).

Edit linked source directly; content changes do not need another apply. The
[editing guide](docs/manifest-management.md) covers structural changes, orphan
removal, native declarations and local state. To link settings without installing
tools or shell plugins, run `mise dot apply`. Its preload hook can download the
declared JS; use `mise dot apply --dry-run` to preview without running hooks.

Use ignored `mise.local.toml` for machine-specific choices. For example,
`[bootstrap]` with `dotfile_groups = ["shell", "vim"]` selects those groups;
omitting that selection uses all declared groups. Explicit workspace bindings
and the independent preload declaration are not group selections. Review
`mise dot status` and use native prune/unapply when removing a deployed group;
deselecting it alone leaves orphaned links.

## Shell settings

### Claude Code agent-summary preload

This integration is enabled by default. A mise post-dotfiles hook downloads a pinned
[no-agent-summary hook](https://gist.github.com/flamerix-ai/c3905705cc4205e5de3011fa2e74efce)
to `~/.local/share/no-agent-summary.js`; `.zshenv` adds it to `BUN_OPTIONS`.
The hook suppresses periodic background-agent progress summaries, so the agent
panel and SDK `task_progress.summary` stop receiving those summaries. It is an
unofficial runtime hook whose compatibility with Claude Code updates is owned by
the upstream project, not a guarantee of this configuration.

The feature's declaration, acquisition adapter and static environment adapter
live in `features/claude-no-agent-summary/`. Its native `mise.toml` owns
the `claude_no_agent_summary` mode (`"on"` or `"off"`) and the pinned URL.
To disable it on one machine,
put this override in the checkout's ignored `mise.local.toml`:

```toml
[vars]
claude_no_agent_summary = "off"
```

Applying `"off"` removes the downloaded JS without fetching, while the retained
environment adapter strips its preload from new Zsh environments. Other Bun
options are preserved. The JS is not tracked in Git and shell startup does not
download it. Set the mode to `"on"` or remove the override to re-enable it.

Before disabling, finish existing Claude/Bun sessions and stop any Claude Code
daemon through its normal controls: those processes retain loaded code and
inherited options. Then change the flag, review `mise dot apply --dry-run`, run
`mise dot apply`, and start a fresh Zsh before using Bun or Claude again.
Changing the flag alone does not perform acquisition/removal. Do not delete the
JS alone while old environments refer to it. Failed downloads leave the previous
file intact and fail the command; they do not roll back unrelated linked files.
Disable/apply before retiring the feature's source and deployment entry.

### Interactive configuration

Interactive Bash and Zsh use the following ownership boundaries under
`~/.config/shell/`. Noninteractive shells do not initialize this profile.

| Location | Responsibility |
| --- | --- |
| `platforms/init.sh`, `platforms/macos.sh`, `platforms/linux.sh` | OS selection and defaults: listing flags and SDK/locale |
| `device/local.sh` (unmanaged) | This device's paths and overrides; loaded after OS defaults, before tools |
| `preferences.sh` | Shared editor, clipboard, aliases and command preferences |
| `integrations/` | Optional Homebrew, mise/Pixi, Slurm and prompt integration on either OS |
| `bash/`, `zsh/` | Shell-native handoff, completion, history and plugin mechanics |

The corresponding source is `config/shell/lib/`; `device/` remains private runtime
input outside that tree. Bash/Zsh entrypoints live beside `lib/` in the source.

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
The default Pixi manifest is resolved through the bound mise workspace to its
sibling `workspaces/pixi-base/pixi.toml`, without a generated absolute path. Explicit
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
or edit `workspaces/mise/conf.d/tools.toml` and run `mise install`. The same catalog
is included by repository bootstrap. Tool requests retain their
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

Use Python 3.11+, mise, Git, curl, Bash, Zsh, Vim and Neovim. Expect and tmux enable
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
Deployment tests exercise native mise with temporary homes and file-URL assets;
they do not fetch the real preload or install the declared tools. Optional native
Bun, Ghostty and daem checks skip when unavailable. CI installs current mise.

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

## Ghostty

Mise links files from `config/ghostty/` into `~/.config/ghostty/`.
The selected theme is `one-half-light.conf`; `catppuccin-latte.conf` is also
available. Other local themes and runtime state remain unmanaged and are not
removed by apply. Edit the managed source for persistent shared changes.

The font-family entries retain their order. Install Ghostty and any desired
fonts separately; configuration placement does not require them to be present.
`window-save-state = always` is a native macOS setting that Ghostty ignores on
Linux.

On macOS, Ghostty reads files in
`~/Library/Application Support/com.mitchellh.ghostty/` after the XDG configuration.
Settings there remain local and can override the managed configuration.
