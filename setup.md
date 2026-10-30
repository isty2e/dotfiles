# Setup

Install current [mise](https://mise.jdx.dev/getting-started.html) with native
bootstrap/dotfile support, Git, a POSIX shell and HTTPS-capable curl.
Run the commands below from the checkout unless another directory is shown.

## Bootstrap a checkout

**Already have configuration?** Follow [first-apply preparation](#first-apply-on-an-existing-home)
before applying. For existing editor links or shared runtimes, also use the
[editor migration guide](docs/editor-migration.md).

Bootstrap links settings, installs CLI tools and prepares shell plugins using
third-party installers. It also enables the optional
[Claude Code summary hook](#claude-code-agent-summary-preload) by default.

```sh
git clone https://github.com/isty2e/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
mise trust mise.toml &&
  mise dot apply &&
  mise trust "$HOME/.config/mise/conf.d/tools.toml" &&
  mise bootstrap
```

Keep this order: place the configuration first, then trust the catalog at its
global path. Trusting only its source path can leave bootstrap's tool lookups
blocked. If you created `mise.local.toml`, run `mise trust mise.local.toml` before
applying it; approve only your known configuration files.

Open a new shell afterward. The account's login shell and system packages are
unchanged. Continue with any [additional setup](#additional-setup) you need.

> [!WARNING]
> A failed apply or installation can leave earlier steps in place. Preserve the
> affected files, resolve the reported conflict or installation error, then retry;
> completed steps are not automatically backed up or rolled back.

## Mise deployment

To place settings without installing CLI tools or shell plugins:

```sh
mise dot apply --dry-run
mise dot apply
```

Apply also runs the summary-hook download/removal; dry-run skips hooks. For first
setup, use the [bootstrap sequence](#bootstrap-a-checkout) above.

For ordinary edits, use the [configuration reference](docs/manifest-management.md):
it lists source paths, reload steps, group selection and removal commands.

## Additional setup

Bootstrap does not install scientific environments, agent resources or editor
plugins, or sign in to accounts. Prepare those separately:

| What you need | Next step |
| --- | --- |
| Scientific Python environment | Follow [Pixi base environment](#pixi-base-environment) below. |
| Agent skills and instructions | Follow [Agent environment](#agent-environment) below; private sources need credentials. |
| Vim plugins | Open Vim, run `:VimSetup`, inspect `:PlugStatus`, then restart. See [Vim setup and recovery](docs/vim.md). |
| Neovim plugins | Run `:NvimSetup` explicitly. See [Neovim](docs/neovim.md) for separate language-server/parser setup. |
| Ghostty and fonts | Install them separately; see [Ghostty](#ghostty) for the managed themes. |
| Pi themes | Follow [manual theme installation](pi/README.md#install). |

### Pixi base environment

```sh
cd "$HOME/dotfiles/workspaces/pixi-base"
pixi install
```

Use a suitable CUDA host for the Linux environment. A virtual CUDA override does
not provide a GPU; minimal Linux systems may also need libXrender and libXext for
chemistry/image operations.

### Agent environment

`~/.config/daem` points to `workspaces/daem`. Review the resolved resources before
deploying them:

```sh
daem lock
daem apply --dry-run
daem apply
```

## Shell settings

Interactive Bash and Zsh read `~/.config/shell/device/local.sh` for machine paths
and preferences, and the optional `credentials.sh` beside it for secrets.
See [shell settings and defaults](docs/manifest-management.md#shell-settings) and
[private device files](docs/manifest-management.md#private-device-files).

On Linux SSH connections, interactive Bash replaces itself with an available
Zsh. To stay in Bash, pass `DOTFILES_KEEP_BASH=1` when invoking it, for example
`DOTFILES_KEEP_BASH=1 bash`; setting it in `local.sh` is too late. This does not
change the account's login shell or noninteractive commands/jobs.

### Claude Code agent-summary preload

The default-on [no-agent-summary hook](https://gist.github.com/flamerix-ai/c3905705cc4205e5de3011fa2e74efce)
suppresses periodic background-agent summaries in the agent panel and SDK
`task_progress.summary`. It is an unofficial runtime hook; Claude Code updates
may break it. Its declaration and adapters live in `features/claude-no-agent-summary/`.

To disable it on one machine:

1. Finish existing Claude/Bun sessions and stop any Claude Code daemon through its
   normal controls; already running processes retain the loaded hook.
2. Add this to the checkout's ignored `mise.local.toml`:

   ```toml
   [vars]
   claude_no_agent_summary = "off"
   ```

3. If this is a new local configuration, run `mise trust mise.local.toml`. Review
   `mise dot apply --dry-run`, then run `mise dot apply`.
4. Start a fresh Zsh before using Bun or Claude again.

Apply removes `~/.local/share/no-agent-summary.js` without fetching and clears its
preload from new Zsh environments, preserving other Bun options. Changing the
flag alone does not remove it; do not delete the JS while old environments still
refer to it. Disable and apply before removing the feature's source/declaration.

Set the mode to `"on"` or remove the override, then apply to re-enable it. Apply
downloads the pinned JS and `.zshenv` adds it to `BUN_OPTIONS`; startup downloads
nothing. Failed downloads keep the previous file and fail the command.

### Repair or update shell plugins

Run from the operational checkout:

```sh
sh scripts/install-shell-plugins.sh
# To resolve updated plugin revisions instead:
sh scripts/install-shell-plugins.sh --update
```

The installer uses `workspaces/sheldon/plugins.toml` and switches the active
generation under `~/.local/share/dotfiles/sheldon` only after success. A failure
keeps the current generation; previous generations and older plugin checkouts
are left in place. Shell startup loads prepared plugins without installing them.

## First apply on an existing home

From the cloned checkout, prepare existing settings before the first apply:

1. Back up startup files, managed settings, link destinations and native workspaces
   to a private location outside Git. Keep the operating checkout at a stable path.
2. Compare private settings with [device files](docs/manifest-management.md#private-device-files);
   do not import credentials or whole startup files into shared sources.
3. Trust this checkout with `mise trust mise.toml`, then review `mise dot diff`,
   including link destinations. Move only reviewed conflicting files aside,
   merging the settings you want to keep.
4. After resolving conflicts, run the trust/apply/bootstrap commands from
   [bootstrap](#bootstrap-a-checkout); do not clone the checkout again.

Existing regular files conflict even when their contents match. Existing links
can be repointed without `--force`, so inspect their targets too. Do not force
adoption past an unexpected conflict.

### Native workspace migration

For **mise**, merge tools into `workspaces/mise/conf.d/tools.toml` and settings
into `workspaces/mise/config.toml`, preserving other local files. Installed
runtimes stay in mise's data directory.

For **daem**:

1. Back up the whole existing directory, not just its manifest.
2. Merge the manifest and preserve `daem.lock.toml` and `.daem/` in `workspaces/daem`.
   Keep directory mode 0700 and manifest mode 0600; bootstrap also sets these before binding.
3. After linking, review `daem apply --dry-run`. Stop on unexpected adoption,
   deletion or ownership changes rather than resetting state.

Move only the reviewed old workspace directories aside to make room for these
directory bindings. Neovim instead uses individual configuration links: preserve
its local `lazy-lock.json` if you use native restore, and follow the
[editor migration guide](docs/editor-migration.md) for existing runtimes.

Git does not move ignored state along with declarations. Copy the needed local
state before switching bindings, and keep the original directories until their
contents are safe.

> [!WARNING]
> Do not move a live Pixi `.pixi` prefix. Build and verify a separate environment,
> then switch activation while leaving the old environment and running processes
> intact. Use `DOTFILES_PIXI_BASE_MANIFEST` in `device/local.sh` to select the old
> manifest while preparing the new one.

## Ghostty

Settings and themes live in `config/ghostty/`, linked to `~/.config/ghostty/`.
The selected theme is `one-half-light.conf`; `catppuccin-latte.conf` is also
available. Apply leaves other local themes and runtime state alone. Install
Ghostty and your fonts separately; placement does not require them. Preserve the
configured font-family order when editing.

On macOS, files in `~/Library/Application Support/com.mitchellh.ghostty/` can
override the managed XDG settings. `window-save-state = always` is macOS-only
and ignored on Linux.

## Tests

These are repository regression checks, not part of the bootstrap command.
Use Python 3.11+, mise, Git, curl, Bash, Zsh, Vim and Neovim; install Python test
dependencies from `tests/keymaps/requirements.txt`. Expect and tmux enable session
checks; macOS tests can also use Homebrew Bash.

```sh
sh tests/run.sh
```

Tests use temporary homes, installation doubles and local preload assets rather
than installing the declared environment. Native mise/Pixi checks use detected
tools or `MISE`/`PIXI` overrides; optional Bun, Ghostty and daem checks skip when
unavailable. CI installs current mise. Network-backed acquisition and plugin-loaded
checks are separate: see [Vim](docs/vim.md#tests), [Neovim](docs/neovim.md#verify-without-deployment)
and [keymaps](docs/keymaps.md).

## Commit checks

Run `pre-commit install` to enable Gitleaks. Review diffs and keep credentials out
of declarations; the hook is a check, not permission to publish private files.

## Slurm commands

`sbatchall` and `slurm-cancel` are placed in `~/.local/bin`. Inspect their help and
selected jobs before cancellation.
