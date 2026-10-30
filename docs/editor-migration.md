# Migrate an existing editor setup

Use this guide when existing editor configuration points to another checkout,
shared directory or cloud-synced runtime. For a new home, start with
[setup](../setup.md#bootstrap-a-checkout).

For existing shell files, also follow
[first-apply preparation](../setup.md#first-apply-on-an-existing-home). Keep backups
outside the checkout and do not bulk-import pre-existing files.

## Before applying

1. Stop the editors whose configuration will change.
2. Record existing link targets and back up the affected files. Preserve local
   edits, Git history and generated runtime files separately from configuration.
3. From the intended checkout, inspect `mise dot status`, `mise dot diff` and
   `mise dot apply --dry-run`. Move only reviewed conflicting files aside.
   Existing file links can be repointed without `--force`; preserve their old
   targets before adopting the new source.

For configuration deployment, use `mise dot apply`; it also runs the optional
preload's acquisition/removal hook. `mise bootstrap` additionally installs tools
and prepares shell plugins. Neither command runs `:VimSetup` or `:NvimSetup`,
installs language servers/parsers, or installs the Pixi environment.

For a rehearsal, use a disposable checkout and temporary `HOME`, `TMPDIR`, XDG
configuration/cache/data/state paths and mise configuration/cache/data/state
paths. Changing HOME alone still links native workspaces to the checkout, so
native authoring could modify its real manifests and state. The deployment tests
copy the source and use a file-URL preload fixture to avoid downloads. Do not run
the real default-on hook unintentionally in a rehearsal.

## Vim

Record both `~/.vimrc` and `~/.vim` link targets before replacing either. Mise
links `.vimrc` to `config/vim/vimrc`; it does not manage the runtime directory.

If `~/.vim` points to the expected shared runtime, remove only the link and create
a local directory before running `:VimSetup`. Stop if the target is an unexpected
file or directory. Never recursively remove the shared destination. Keep the old
runtime available until you have checked the local one.

To roll back, preserve the new local runtime under another name and restore both
recorded links. Before applying again, choose the matching source revision and
review its diff. Restoring links alone does not change mise's desired state;
another apply could replace the vimrc again.

## Neovim

If `~/.config/nvim` is a Git working tree, preserve it outside the target path
before applying. Keep its history rather than deleting `.git` or applying over
the checkout. The configuration source is
`config/nvim/`; plugin data, state and caches remain separate.

Follow [Neovim setup](neovim.md) after placement. Replacing configuration does
not isolate or remove old plugin data. Archiving or deleting the former checkout
is a separate choice; configuration placement does not require it.

## Helix

When replacing a linked configuration directory with a local directory, preserve
the original link and local runtime first. Keep `runtime/grammars` and its source
cache under the local `~/.config/helix/`; do not copy them into the source checkout
or add a persistent removal rule. Stop Helix during the move so an existing
process cannot keep using the old runtime paths. Later applies leave that
unmanaged runtime in place.

For rollback, preserve newer configuration, restore the runtime and original
link, and select the matching source checkout before applying again.

## Zed

Back up settings and keymaps before replacing linked files. The source contains
UI, language and provider preferences, not credentials, sessions or extension
state. Install the required fonts, theme extensions and language tools separately;
use Zed's own login flow for accounts. Placement keeps the configured provider
choices rather than selecting new ones.

## Placement tests

From the checkout root:

```sh
python -m unittest discover -s tests/deployment -v
```

The tests use mise from `PATH` or `MISE` and skip if it is unavailable. They
exercise native links, direct source edits, local-file conflicts, pruning and
unapply in isolated homes and source copies, including unmanaged runtime/private
data preservation. They do not change the real home or install declared tools.
