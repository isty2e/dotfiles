# Editing managed configuration

`mise.toml` declares the deployment. Native settings live under `config/` and are
linked individually into the home directory. Edit their repository source, or
open it through mise from the checkout:

```sh
mise dot edit ~/.config/helix/config.toml
git diff
```

Edits to an existing linked source are immediately visible through the link.
There is no copy or synchronization step; applications may need a reload or a new
session. Updating the linked checkout also updates the active configuration.
Use another worktree when an experiment or request needs source-only isolation,
not as a prerequisite for ordinary editing. Keep the operating checkout at a
stable path while home links point into it.

## Tool declarations

| Declaration | Source | Native editing path |
| --- | --- | --- |
| CLI tools | `workspaces/mise/conf.d/tools.toml` | `mise use --global …` |
| Mise settings | `workspaces/mise/config.toml` | Edit settings or use native mise commands |
| Agent environment | `workspaces/daem/daem.toml` | `daem add …`, then review native lock/apply |
| Python environment | `workspaces/pixi-base/pixi.toml` | Run Pixi there or pass `--manifest-path` |
| Shell plugins | `workspaces/sheldon/plugins.toml` | Edit, then run `sh scripts/install-shell-plugins.sh` |
| Neovim plugins | `config/nvim/lua/plugins/` | Edit, then use `:NvimSetup` or `:Lazy` explicitly |

The repository and global mise configuration read the same tool catalog. Global
write-target routing sends new `mise use --global` declarations there too. Mise
and daem use **directory** links so native atomic saves reach the repository;
do not replace them with individual-file links. The pre-dotfiles hook protects
the actual daem workspace as 0700 and its manifest as 0600 before binding it.

## Structural changes and preparation

For new files, removed files, changed link targets or group selection, review and
apply the deployment from the checkout:

```sh
mise dot diff
mise dot apply --dry-run
mise dot apply
```

Groups deploy Git-indexed source files, so stage a newly authored file before
trying its deployment. Untracked generated files are not automatically deployed.
Put per-machine group choices or feature overrides in the ignored
`mise.local.toml`; keep credentials in the private shell device files instead.

Removing a declaration alone does not remove an installed target. For groups,
review orphaned files with `mise dot status`, then use `mise dot apply --prune`
or `mise dot unapply --group <name>`. For an explicit target, run
`mise dot unapply <target>` before deleting its declaration. These operations
preserve unrelated files; do not use `--force` to bypass unexpected local changes.

`mise dot apply` does not install tools, Pixi environments, shell plugins or editor
plugins, and does not deploy daem resources. It does run the permission and
[optional preload](../setup.md#claude-code-agent-summary-preload) hooks. Preload
acquisition uses its declared URL; disabling it removes its JS without fetching.
`mise bootstrap` additionally installs the declared tools and prepares shell
plugins. Native failures propagate, but completed steps are not rolled back.

## Unexpected local changes

An application can replace an individual link with a regular file when saving.
Mise then refuses to overwrite it, even if its bytes match the source. Compare
both files and preserve the wanted changes before restoring the link. Native
`mise dot add` can capture a deliberately selected target; review the source and
Git diff rather than importing the whole home.

Mise can repoint an existing link to a different source without `--force`; it is
not a universal link-adoption guard. Review link targets and preserve their
original destinations during the [first handoff](../setup.md#first-apply-on-an-existing-home).

## Local state and boundaries

Git tracks authored configuration and manifests, not locks or installation
results. Pixi's `.pixi/` and `pixi.lock`, daem's `.daem/` and `daem.lock.toml`,
mise's local configuration and Neovim's live `lazy-lock.json` remain local.
Ignored locks and ownership state are not disposable. Do not use
`git clean -fdx` on the operating checkout or remove it as a rollback strategy.

Exact dependency resolution from a Git commit is a **NON-GOAL**. Preserve the
declarations' explicit compatibility constraints, including the Tree-sitter
legacy-API pin. A local lock can support native restore on its machine; it is not
a shared installation snapshot. Git rollback does not roll back installed tools.

Private device files and installed agent resources retain their existing owners.
Shared instruction source lives in `agents/AGENTS.md`; editing it here does not
update installed copies. Daem owns installed skills and instructions; deployment
of these settings does not deploy those resources. Pi themes retain their
[manual installation](../pi/README.md#install).
