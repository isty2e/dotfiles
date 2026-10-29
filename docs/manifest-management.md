# Editing managed configuration

Edit ordinary settings in `home/`, review the Git diff, then apply them with
chezmoi. `chezmoi source-path <target>` locates a managed file's source;
`chezmoi edit <target>` opens it. Agents can edit the source files directly.
Do not treat an edit request as permission to deploy it to the current home.

```sh
chezmoi edit ~/.config/helix/config.toml
chezmoi diff ~/.config/helix/config.toml
chezmoi apply --less-interactive --error-on-conflict ~/.config/helix/config.toml
```

Generated chezmoi configuration sets `lessInteractive = true`. Existing users
must add that setting to their local chezmoi configuration or review and run
`chezmoi init` to regenerate it. Bootstrap and the update example below also pass
the conflict flags explicitly. A conflict can leave earlier entries applied;
chezmoi does not create a backup or roll back the operation.

## Tool declarations

| Declaration | Source | Native editing path |
| --- | --- | --- |
| CLI tools | `workspaces/mise/config.toml` | `mise use --global …` |
| Agent environment | `workspaces/daem/daem.toml` | `daem add …`, then review and use native lock/apply |
| Python environment | `workspaces/pixi-base/pixi.toml` | Run Pixi in that directory or use `--manifest-path` |
| Shell plugins | `workspaces/sheldon/plugins.toml` | Edit, then run `sh scripts/install-shell-plugins.sh` |
| Neovim plugins | `home/private_dot_config/nvim/lua/plugins/` | Edit declarations, apply, then use `:NvimSetup` or `:Lazy` |

Chezmoi links the **directories** `~/.config/mise` and `~/.config/daem` to their
workspaces. Native commands and atomic file replacement therefore reach the same
source, rather than detached copies. Do not replace these with individual-file
links. The daem workspace is protected as 0700 and its initial manifest as 0600
before its binding is installed. Preserve private permissions when editing it.

Git tracks authored settings and dependency declarations, not installation
results. Pixi's `.pixi/` and `pixi.lock`, daem's `.daem/` and `daem.lock.toml`,
and Neovim's live `lazy-lock.json` stay local. Required locks and ownership state
are **not disposable** just because Git ignores them. Do not use `git clean -fdx`
on the operational checkout or delete it as a rollback strategy.

Exact dependency resolution from a Git commit is a **NON-GOAL**. Preserve explicit
compatibility constraints in declarations, including the Tree-sitter legacy-API
pin. A local lock may support native restore on that machine, but it is not a
shared installation snapshot.

## Apply, install and update

Ordinary `chezmoi apply` places configuration and bindings; it does not run mise,
Pixi, daem, editor setup or Sheldon installation. Its only setup script protects
the daem workspace's private permissions. `sh bootstrap.sh` explicitly installs
mise tools and prepares shell plugins after successful configuration placement.
Other installation and update operations remain with their native tools.

Keep the operational checkout at a stable path. Use separate worktrees for
speculative changes: `workspaces/` files are live inputs to native commands, even
before another chezmoi apply. Git rollback does not roll back installed packages.

Before pulling, commit or deliberately set aside declaration edits, and inspect
any differences in deployed ordinary files. Then, from the operational checkout:

```sh
git pull --ff-only
chezmoi diff
chezmoi apply --less-interactive --error-on-conflict
```

Run the relevant native install/update only when intended. No update-all wrapper
or exact chezmoi runtime-version allowlist is used. CI's chosen chezmoi version is
a test input, not a restriction on users' installed versions.

## Unexpected live edits

If a person or program changed a deployed ordinary file, compare it with its
source. Preserve the wanted changes in the source and review the result before
applying. For an ordinary non-template file, a deliberately selected
`chezmoi re-add <target>` is also available after confirming the source has no
independent changes. Do not bulk import the home: private and unrelated changes
must not enter Git. There is no custom reverse-capture command.

Secrets, machine-specific `local.sh`, credentials and installed agent resources
remain with their existing owners. Native daem commands own installed skills and
instructions; do not edit generated installations to bypass their manifest.
See [setup and migration](../setup.md) before adopting this layout on an existing
home. Pi themes retain their [manual installation](../pi/README.md#install).
