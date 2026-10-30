# Editing managed configuration

Edit the repository source or open it through mise from the checkout:

```sh
mise dot edit ~/.config/helix/config.toml
git diff
```

Existing links reflect source edits immediately; reload the application or open
a new shell as needed. No copy/sync step is required. Keep the operating checkout
at a stable path, and use another worktree for experiments that must not affect
the active configuration. Updating the linked checkout also changes active settings.

## Where to edit

| Change | Source | Apply the change |
| --- | --- | --- |
| Shared shell aliases/editor defaults | `config/shell/lib/preferences.sh` | Open a new shell. |
| Bash/Zsh options | `config/shell/bashrc`, `config/shell/zshrc` | Open a new shell. |
| OS-specific defaults | `config/shell/lib/platforms/` | Open a new shell. |
| Machine paths and private credentials | [Private device files](#private-device-files) | Open a new shell; keep them outside Git. |
| Vim, Neovim, Helix, Zed, Ghostty, Starship settings | Corresponding directory under `config/` | Reload or restart that application. |
| Link targets and groups | `mise.toml`, or `mise.local.toml` for machine choices | Follow [structural changes](#structural-changes-and-preparation). |
| Claude Code summary hook | `mise.local.toml` override | Follow [enable/disable instructions](../setup.md#claude-code-agent-summary-preload); editing the flag alone is not enough. |

## Tool declarations

| Change | Source | Apply the change |
| --- | --- | --- |
| CLI tools | `workspaces/mise/conf.d/tools.toml` | Use `mise use --global`, or edit and run `mise install`. |
| Mise settings | `workspaces/mise/config.toml` | Edit directly or use native mise commands. |
| Agent environment | `workspaces/daem/daem.toml` | Use native `daem add`, resolve with `daem lock`, then review/apply. |
| Scientific Python environment | `workspaces/pixi-base/pixi.toml` | Use `pixi add`, `pixi remove`, `pixi update` or `pixi install` in that workspace. |
| Shell plugins | `workspaces/sheldon/plugins.toml` | Run `sh scripts/install-shell-plugins.sh`. |
| Neovim plugins | `config/nvim/lua/plugins/` | Use `:NvimSetup` or `:Lazy` explicitly. |
| Shared instruction source | `agents/AGENTS.md` | Manage installed copies separately with daem. |

Mise's global commands and repository bootstrap use the same CLI catalog,
including new `mise use --global` declarations. Keep mise/daem workspace bindings
as **directory** links so native atomic saves update the source. Other settings
use individual file links.

## Shell settings

Set machine overrides in `~/.config/shell/device/local.sh`. It loads after OS
defaults and before tool integrations. Bash/Zsh options and history defaults are
set before it, so later setup keeps your overrides. Noninteractive commands and
jobs do not load this interactive profile.

| Setting | Default | What to change |
| --- | --- | --- |
| `EDITOR`, `VISUAL` | `hx` when `EDITOR` is unset; `VISUAL` follows `EDITOR` when unset | Set either in `local.sh`. `vi=vim` and `v="nvim -p"` remain separate aliases. |
| `DOTFILES_RSYNC_BACKUP_DIR` | `~/rsync` | Select the backup directory used by `cpv`. |
| `BREW_LOCATION` | Auto-detected if available | Set the full path to this device's `brew` executable. |
| `DOTFILES_PIXI_BASE_MANIFEST` | Bound checkout's `workspaces/pixi-base/pixi.toml` | Select an existing base manifest elsewhere. |
| `PIXI_ENVS_HOME` | Unset | If set, selects `$PIXI_ENVS_HOME/base/pixi.toml` unless the explicit manifest override is set. |
| Bash history | `HISTSIZE=1000`, `HISTFILESIZE=2000`, `~/.bash_history` | Override native history variables in `local.sh`. |
| Zsh history | `HISTSIZE=4096`, `SAVEHIST=4096`, `~/.zsh_history`, `SHARE_HISTORY` on | Override native history variables/options in `local.sh`. |
| `DOTFILES_BASH_HISTORY_SYNC` | `0` | Set to `1` for prompt-time append/read sharing; normal exit-time persistence stays enabled. |
| Zsh completion | Case-insensitive, then approximate matching with `max-errors=2` | Override `zstyle` rules in `local.sh`; command-name correction confirmation is off. |
| Zsh input display | Gray autosuggestions (`fg=#808080`); fzf-tab uses description groups and `LS_COLORS` | Override completion styles/plugin variables in `local.sh`. |
| `FZF_DEFAULT_COMMAND` | `fd --type f` | Override standalone fzf's file source; this is not the completion candidate source. |

If fzf-tab is unavailable, check fzf initialization: a missing or failed fzf
initialization skips that selector while leaving other plugins available.

To keep Bash during a Linux SSH session, pass `DOTFILES_KEEP_BASH=1` when starting
it: `DOTFILES_KEEP_BASH=1 bash`. The handoff runs **before** `local.sh`, so that
file cannot prevent it. Already active Zsh sessions also suppress a repeated handoff.

> [!NOTE]
> History sharing is best effort: Bash can trim to `HISTFILESIZE`, and Zsh rewrites
> its shared history. Do not rely on loss-free concurrent recording on NFS. Consider
> Zsh's [HIST_FCNTL_LOCK](https://zsh.sourceforge.io/Doc/Release/Options.html#History),
> or a local `HISTFILE` if cross-host sharing is unnecessary.

Mise reuses installed tools without startup installation. Pixi activates an
already installed base environment only when no project/Conda/virtualenv is
active; it does not search old `~/pixi-env` or `~/pixi_envs` locations. Starship
supplies the prompt when installed. Open a new shell for changed environment
settings; existing tmux sessions keep their environments.

## Private device files

Use these paths on either OS; missing files are skipped:

| File | Contents |
| --- | --- |
| `~/.config/shell/device/local.sh` | Machine paths, preferences and optional integrations. |
| `~/.config/shell/device/credentials.sh` | Trusted shell assignments; loaded variables are exported to child processes. |

Both files execute shell code and stay outside Git. Create the private directory:

```sh
mkdir -p "$HOME/.config/shell/device"
chmod 700 "$HOME/.config/shell/device"
```

If you need credentials, create the file and restrict access **before** adding them:

```sh
touch "$HOME/.config/shell/device/credentials.sh"
chmod 600 "$HOME/.config/shell/device/credentials.sh"
```

The loader skips credentials with a warning unless the file is readable, owned
by you and inaccessible to group/other users. Existing destination-directory
permissions are otherwise left as they are.

## Structural changes and preparation

For new files, changed targets or group selection:

1. Stage newly authored files with `git add`; groups deploy Git-indexed files,
   not arbitrary generated/untracked files.
2. Review and apply from the checkout:

   ```sh
   mise dot diff
   mise dot apply --dry-run
   mise dot apply
   ```

For per-machine choices, create the ignored `mise.local.toml` and trust it with
`mise trust mise.local.toml`. For example, select only the shell and Vim groups:

```toml
[bootstrap]
dotfile_groups = ["shell", "vim"]
```

Without a selection, all groups apply. The explicit mise/daem workspace bindings
and independent preload declaration are not group selections. Keep secrets in
device files rather than this local mise configuration.

Removing a declaration or deselecting a group leaves orphaned links. Review
`mise dot status`, then use `mise dot apply --prune`. To remove a group before
changing its declaration, for example Vim settings:

```sh
mise dot unapply --group vim
```

For a single target, use native `mise dot unapply` with that target before deleting
its declaration. These commands preserve unrelated files. See
[setup](../setup.md#mise-deployment) for apply versus full bootstrap.

## Unexpected local changes

| Symptom | What to do |
| --- | --- |
| An editor replaced a link with a regular file | Compare it with the source, merge wanted edits, move the conflicting file aside, then reapply. Matching bytes alone do not avoid a conflict. |
| You deliberately want to capture a home file | Use native `mise dot add` for that target, then inspect the source and Git diff; do not import the whole home. |
| An existing link points somewhere else | Review and preserve its destination before [first apply](../setup.md#first-apply-on-an-existing-home); mise can repoint it without `--force`. |

Do not use `--force` to bypass unexplained local changes.

## Local state and boundaries

Git tracks authored settings/manifests, not installation results. Keep Pixi's
`.pixi/` and `pixi.lock`, daem's `.daem/` and `daem.lock.toml`, `mise.local.toml`
and Neovim's live `lazy-lock.json` local. Preserve locks and ownership state when
[moving workspaces](../setup.md#native-workspace-migration).

> [!WARNING]
> Do not run `git clean -fdx` on the operating checkout: ignored environments,
> locks and ownership state are valuable local data. Do not delete the checkout
> as a rollback strategy while home links still use it.

Git restores declarations, not installed tools. Exact installed-version
reproduction from a commit is not supported; native local locks can support
restore on their machine. Retain explicit compatibility pins when editing versions.
