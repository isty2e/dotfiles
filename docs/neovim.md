# Neovim configuration

Neovim 0.11+ with lazy.nvim and individually configured plugins, without a
distribution such as AstroNvim or LazyVim. You need Git and a true-color terminal.
A Nerd Font adds file icons. Telescope live grep needs ripgrep; its native fzf
sorter also needs a C compiler and Make.

The source is `home/private_dot_config/nvim/`. Paths below are relative to that
directory. The [former repository](https://github.com/isty2e/dotfiles.nvim) keeps
history; this checkout is the source for edits. [Vim](vim.md) remains independent.

## Install and update

Chezmoi places the contents at `~/.config/nvim`; see
[setup](../setup.md#chezmoi-placement). If that path already contains configuration
or a Git checkout, follow [the migration guide](editor-migration.md#neovim) first.
Without chezmoi, preserve the old target and copy only the configuration directory's
contents into an empty target, not the whole dotfiles repository. Plugin data,
state and caches are separate; selecting another config does not isolate them.

Start Neovim, run `:NvimSetup`, inspect `:Lazy`, then restart. Setup downloads a
missing lazy.nvim manager from its `stable` branch and installs missing plugins
and unfinished builds at lockfile revisions. It reuses existing managers and
healthy checkouts without running update, sync, clean or restore.

Setup uses the network and executes third-party plugin code. Run it explicitly:
ordinary startup and chezmoi apply do not install plugins, language servers or
parsers, or check for updates. Without lazy.nvim, startup warns and keeps options,
core maps and `:NvimSetup` available, but not the plugin features.

A failed clone leaves no published manager, so rerun `:NvimSetup` to retry. If an
incomplete manager directory already exists, setup leaves it alone; move it aside
before retrying. Inspect plugin failures and retries in `:Lazy`.

Use `:Lazy restore` to return plugins to `lazy-lock.json` revisions. After an
intentional `:Lazy update`, review and commit the lockfile. The Tree-sitter
declaration pins its legacy API; a newer API needs configuration changes.

For the native Telescope sorter, run `make` in the installed
`telescope-fzf-native.nvim` directory. Without its built library, Telescope uses
its ordinary sorter. Install desired parsers explicitly with `:TSInstall`;
missing parsers leave ordinary editing available. Tree-sitter indentation is
disabled.

## Features

- **Themes:** Newpaper Light is the default. GitHub Light variants are available
  through `,ft` or `:colorscheme`. Theme declarations live in
  `lua/plugins/themes.lua`.
- **Language support:** native Neovim LSP with per-language settings in
  `lua/config/lsp.lua`. Completion uses nvim-cmp with LSP, buffer and path sources;
  snippet expansion uses Neovim's native engine.
- **Navigation:** neo-tree is the only file explorer; Telescope provides file,
  text, buffer and theme selection. Their declarations own their local keys.
- **Editing and visibility:** Comment.nvim, Gitsigns, Satellite's scrollbar,
  indentation guides, reference highlighting and nvim-notify. The statusline is
  native Neovim configuration rather than a separate plugin.

The configuration does not include authenticated AI completion, a debugger,
an embedded-terminal plugin, session restoration or a Markdown-renderer bundle.
Installing it leaves old plugin caches and other profiles' state in place.

## Language tools

Install language servers separately. The config looks on `PATH`, then in
`mason/bin` under Neovim's data directory. It reuses those binaries without loading
Mason or installing tools. A missing executable leaves its service disabled.

| Language | Executable / role |
| --- | --- |
| Python | `zuban server` for types; `ruff server` for diagnostics and formatting |
| Lua | `lua-language-server`, configured for LuaJIT and Neovim's `vim` global |
| Shell | `bash-language-server start` |
| C / C++ / Objective-C | `clangd` |
| Rust | `rust-analyzer` |
| TOML | `taplo lsp stdio` |
| Markdown | `marksman server` |

Use `:checkhealth vim.lsp` to inspect connections. Python formatting selects
Ruff, and Ruff hover is disabled so it does not compete with Zuban. Formatting
is explicit, not automatic on save; Lua server formatting remains disabled.
Use each server's project configuration and check its runtime requirements.

## Keymaps

The leader is comma. Colemak uses `h/n/e/i` for left/down/up/right, `u` for
insertion, `l/L` for Undo/Redo, and `k/K` for next/previous search. See the
[keymap policy](keymaps.md#vim-and-neovim) for display-line movement, operator
motions and literal input.

Edit each kind of binding in its own configuration:

- `lua/config/keymaps.lua`: core maps and personal tab/window gestures. There is
  no full-alphabet translation or runtime layout toggle.
- `lua/config/lsp.lua`: buffer-local LSP keys on `LspAttach`, after Neovim's
  defaults. `E` opens hover when supported; `K` retains previous search.
- `lua/plugins/*.lua`: plugin-owned interactions, including buffer-local maps.
  Neo-tree's `n/e` navigation and `i/u` open/details cycle applies to its
  filesystem, buffer and Git sources. Telescope uses `n/e` in Normal mode;
  Insert-mode queries stay literal. Its displaced list-bottom action is on `I`.

| Keys | Operation |
| --- | --- |
| `,e` | Toggle file explorer |
| `,ff` / `,fg` / `,fb` / `,ft` | Find files / grep / buffers / themes |
| `,k` / `,m` / `,.` | New / previous / next tab |
| `gd` / `gD` / `gr` / `gy` | Definition / declaration / references / type definition |
| `,lr` / `,la` / `,lf` | Rename / code action / format |
| `]c` / `[c` / `,gp` / `,gb` | Next / previous Git hunk / preview / blame |
| Space then `/` | Comment line or selected text |
| `Ctrl-n/p` or `Ctrl-j/k` | Completion selection |
| `Enter` | Confirm an explicitly selected completion |
| `Tab` / `Shift-Tab` | Completion selection or native snippet navigation |

The OS clipboard is explicit through registers such as `"+`; ordinary yanks are
not automatically synchronized to it.

## Verify without deployment

Test explicit setup and its failure/retry behavior without network access:

```sh
sh tests/nvim/run-setup.sh
```

The base tests need only Neovim. With Git and an existing lazy.nvim checkout, a
second tier bootstraps a manager and installs local fixture plugins, checking
lockfile selection and preservation of an existing checkout. Without those
optional inputs, only that native tier is skipped. Set `LAZY` to select a cached
manager and `NVIM` to select the Neovim executable.

The integration runner uses a temporary home, all four XDG directories and a
fixture Git repository. It borrows an existing plugin cache without installing:

```sh
sh tests/nvim/run-keymaps.sh
```

Pass another cache directory as the first argument. To test a chezmoi result,
set `KEYMAP_TEST_CONFIG` to its `.config/nvim`; the default is this repository's
`home/private_dot_config/nvim`. Missing Neovim, Git or the neo-tree cache exits
with code 77; other incomplete caches fail. Checks cover plugin buffers, picker
input, completion, an LSP protocol fixture, comments, themes and the statusline.
They do not check every external language server.

For core editing with no manager/plugins, use an empty home and data directory:

```sh
root=$PWD
scratch=$(mktemp -d)
env -i PATH="$PATH" HOME="$scratch" TMPDIR="$scratch" \
  XDG_CONFIG_HOME="$scratch/config" XDG_DATA_HOME="$scratch/data" \
  XDG_CACHE_HOME="$scratch/cache" XDG_STATE_HOME="$scratch/state" \
  KEYMAP_TEST_CONFIG="$root/home/private_dot_config/nvim" \
  nvim --headless -u NONE -i NONE -l "$root/tests/nvim/core.lua"
rm -rf "$scratch"
```

Temporary paths isolate configuration and file state, not OS credential services
or arbitrary effects of third-party code. The declared profile has no
authenticated integration; review added plugins before running them.
