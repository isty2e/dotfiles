# Editing managed configuration

Chezmoi copies managed configuration into your home. Edit those files normally,
then use `dotfiles-capture` to bring eligible edits back into the checkout. This
workflow covers shell startup files, editor settings, mise, daem and the managed
Pixi manifest.

## Capture local edits

**Do not bulk-capture before the first reviewed apply, including for newly managed
files.** An existing startup file may contain credentials. Follow
[first apply on an existing home](../setup.md#first-apply-on-an-existing-home)
before enrolling it in this workflow.

After adopting the command, preflight and collect local-only edits:

```sh
dotfiles-capture --check
dotfiles-capture
chezmoi git -- diff
```

The command compares native recorded state, desired source and live files before
any capture. A blocked file stops the whole selected batch; unchanged files are
skipped. Use `dotfiles-capture ~/.zshrc` to narrow the declared selection. It needs
Python 3.9+ and the tested chezmoi 2.73.3 adapter; unsupported versions stop without
capture. `home/.chezmoidata.toml` declares automatic-capture paths, with `.` meaning
all eligible managed files. It never enrolls unmanaged files.

The repository does not pin an existing Homebrew installation. A Homebrew upgrade
or a fresh bootstrap that installs a newer chezmoi can therefore stop guarded
capture until that version passes compatibility tests. During that interval,
use native `chezmoi diff` and explicit-target `chezmoi re-add <target>` only after
reviewing which version to keep; then review `chezmoi git -- diff`. This bypasses
the guard, so do not replace it with unrestricted bulk `re-add`.

For a blocked preflight, inspect `chezmoi status` and `chezmoi diff` locally.
Diff output may contain private values.

[The first status column compares live files with chezmoi's recorded state; the
second shows what apply would change](https://www.chezmoi.io/reference/commands/status/).
The leading space in these examples matters:

| Status | Meaning | Before capture |
| --- | --- | --- |
| ` M` | Apply would change a file with no recorded live edit; this can also be an existing file chezmoi has never written. | Review desired output and effective settings, then apply before guarded capture. |
| `MM` | The live file differs from both the recorded state and the desired output. This alone does not prove that the source was also edited. | The guard can collect live-only edits; if the source also changed, reconcile the versions first. |
| ` R` | Apply would run a script. | Review its installation effects; it is not a file to capture. |

Review other additions and deletions too. Reconcile changes manually or with
`chezmoi merge ~/.zshrc`, using the configured merge tool. Native `re-add` is not a
merge: it copies live files into the source, including when only the source has
changed. Avoid bulk capture into an ahead-of-deployment development checkout.

[Without targets, `re-add` captures all modified managed files](https://www.chezmoi.io/reference/commands/re-add/).
Calling it directly bypasses the guard. Keep native `re-add` for deliberate manual
reconciliation, with explicit targets. Review the captured diff and commit with
Git. Nothing commits or pushes automatically.
Keep credentials and machine-only state out of the source. Run `chezmoi managed`
to list the files; a separate inventory is not needed.

Capture also updates chezmoi's comparison state. Save the captured source in Git
before switching revisions, restoring files or stashing it. Applying a revision
without those edits can overwrite the live files without a conflict prompt.

`re-add` leaves templates unchanged and ignores external and non-file entries.
Edit template sources with `chezmoi edit`, then apply their targets. Add new files
explicitly after reviewing them; bulk capture does not enroll unmanaged files.

You can also edit from the source side. For example:

```sh
chezmoi edit --apply ~/.zshrc
```

For other repository edits, review `chezmoi diff` before `chezmoi apply`.

For routine upstream updates after local edits are captured and committed, use
`chezmoi update --less-interactive --error-on-conflict` rather than a separate
pull followed later by apply. This also protects existing targets newly enrolled
by an update. By default, update runs `git pull --autostash --rebase` and then
applies, including installation actions. This is not atomic: if apply fails after
the pull, inspect status and diff again before capture or retry. For manual
resolution, use `chezmoi apply --less-interactive` after reviewing differences.

One checkout is sufficient for ordinary use. A separate development worktree is
optional when preparing changes that must remain separate from live configuration.

See the [capture contract](capture-guard.md) for exclusions, exit statuses and
partial-failure limits. It does not replace secret scanning or protect a later
apply of an older revision.

## Manifests and local state

Mise's source is `home/private_dot_config/mise/config.toml`. The default Pixi
source, `home/pixi-env/base/pixi.toml`, becomes `~/pixi-env/base/pixi.toml`. Under
normal Pixi settings, its lockfile and `.pixi/` environment live beside that file.
Keep them out of the managed source. Copying the manifest does not install or move
an environment; native Pixi commands keep their usual installation behavior.

An existing `~/pixi_envs/base` or custom base path stays where it is. Selecting it
through shell settings does not make its manifest a chezmoi-managed target.
Until that path is explicitly adopted, review and copy only its TOML to or from
the repository source instead of expecting bulk `re-add` to capture it.

Daem's source is `home/private_dot_config/daem/daem.toml`, placed at
`~/.config/daem/daem.toml`. It uses the same copy-and-capture workflow as mise.
Review the existing user manifest before its first managed apply. Keep its
lockfile, caches and installed state local. Placing the manifest does not run
daem lock/apply or deploy agent instructions and settings.

For the installed user configuration, select the manifest explicitly with
`--manifest "${XDG_CONFIG_HOME:-$HOME/.config}/daem/daem.toml"`. Running from the
source directory instead selects a project workspace and can create
`daem.lock.toml` and `.daem/` there. Git and chezmoi exclude both at the source
location. These rules do not delete existing local state.

Pi themes use [manual installation](../pi/README.md#install) from `pi/themes/`.
Agent instructions live under `agents/`. Chezmoi does not deploy Pi settings or
agent instructions, and their installed copies are outside bulk capture.

## Why not mix copies and links?

One copy-and-capture workflow avoids having to remember which edits reach Git
immediately. It also keeps checkout updates separate from installed configuration
until apply. Use a symlink only for a concrete application need or a deliberate
change to that workflow.

Pixi additionally [resolves the manifest's real path during workspace discovery](https://github.com/prefix-dev/pixi/blob/v0.83.0/crates/pixi_manifest/src/discovery.rs),
so linking its manifest into the repository changes its workspace address.
Regular-file placement keeps the manifest and environment together without extra
environment links.
