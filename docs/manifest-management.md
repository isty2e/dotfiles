# Editing managed configuration

Chezmoi copies managed configuration into your home. Edit those files normally,
then use `re-add` to bring the changes back into the checkout. This workflow covers
shell startup files, editor settings, mise and the managed Pixi manifest.

## Capture local edits

**Do not bulk-capture before the first reviewed apply, including for newly managed
files.** An existing startup file may contain credentials. Follow
[first apply on an existing home](../setup.md#first-apply-on-an-existing-home)
before enrolling it in this workflow.

Before each capture, inspect the paths and their status:

```sh
chezmoi status
```

[The first status column compares live files with chezmoi's recorded state; the
second shows what apply would change](https://www.chezmoi.io/reference/commands/status/).
The leading space in these examples matters:

| Status | Meaning | Before capture |
| --- | --- | --- |
| ` M` | Apply would change a file with no recorded live edit; this can also be an existing file chezmoi has never written. | Review and apply the desired source, or capture only an explicitly chosen local edit. Do not bulk-capture this state. |
| `MM` | The live file differs from both the recorded state and the desired output. This alone does not prove that the source was also edited. | Compare the versions and reconcile them before capture. |
| ` R` | Apply would run a script. | Review its installation effects; it is not a file to capture. |

Review other additions and deletions too. Use `chezmoi diff` locally to inspect
content; its output may contain private values. Reconcile changes manually or
with `chezmoi merge ~/.zshrc`, using the configured merge tool. `re-add` is not a
merge: it copies live files into the source, including when only the source has
changed. Avoid bulk capture into an ahead-of-deployment development checkout.

Once differences are reviewed and the remaining edits are the ones you want to
keep, capture them and review the repository diff:

```sh
chezmoi re-add
chezmoi git -- diff
```

[Without targets, `re-add` captures all modified managed files](https://www.chezmoi.io/reference/commands/re-add/).
Review the diff and commit with Git. Nothing commits or pushes automatically.
Keep credentials and machine-only state out of the source. Run `chezmoi managed`
to list the files; a separate inventory is not needed.

To capture only a reviewed, already-adopted file, use a target such as
`chezmoi re-add ~/.zshrc` instead of bulk capture.

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
`chezmoi update` rather than a separate pull followed later by apply. By default,
it runs `git pull --autostash --rebase` and then applies, including installation
actions. This is not atomic: if apply fails after the pull, inspect status and
diff again before capture or retry.

One checkout is sufficient for ordinary use. A separate development worktree is
optional when preparing changes that must remain separate from live configuration.

A [non-interactive capture guard](capture-guard.md) is designed but not installed.
The native commands above do not yet perform that preflight automatically.

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
