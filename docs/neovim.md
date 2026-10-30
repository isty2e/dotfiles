# Neovim configuration

Neovim 0.11+ with lazy.nvim and individually configured plugins, without a
distribution such as AstroNvim or LazyVim. You need Git and a true-color terminal.
A Nerd Font adds file icons. [Vim](vim.md) remains independent.

The source is `config/nvim/`; paths below are relative to that directory.

## Install

1. Place the configuration with [mise setup](../setup.md#mise-deployment).
   If `~/.config/nvim` already contains settings or a Git checkout, follow
   [the migration guide](editor-migration.md#neovim) first.
2. Start Neovim and run `:NvimSetup`. This uses the network and executes
   third-party plugin code.
3. Inspect `:Lazy` for installation results, then restart Neovim.

For standalone placement, preserve the old target and copy only `config/nvim/`'s
contents into an empty `~/.config/nvim`, not the whole dotfiles repository.
Use a separate home/data environment for isolated trials; selecting another
configuration alone does not isolate plugin data, state or caches.

Setup reuses an existing manager or acquires a missing one from the `stable`
reference. It installs missing plugins and unfinished builds from a local
lockfile when present, otherwise declarations, keeping healthy checkouts.

Normal startup and `mise dot apply` do not install plugins, servers or parsers,
or check for updates. Without lazy.nvim, options, core maps and `:NvimSetup`
remain available with a warning. Old caches and other profiles' state stay intact.

## Update and restore

| Goal | Command |
| --- | --- |
| Prepare missing plugins/builds without updating healthy checkouts | `:NvimSetup` |
| Intentionally update plugins | `:Lazy update` |
| Restore plugins to local `lazy-lock.json` revisions | `:Lazy restore` |

Setup does not run update, sync, clean or restore automatically. Plugin declarations
are shared; `lazy-lock.json` stays local and is not deployed by mise.
Retain the Tree-sitter legacy-API pin unless you also adapt the configuration to a
newer API.

## If setup stops

| Problem | Action |
| --- | --- |
| Manager clone fails | Fix the Git/network error, then rerun `:NvimSetup`. Failed clones are not published as the manager. |
| Existing manager path is incomplete | Preserve and move the reported path aside before retrying; setup does not overwrite it. |
| Plugin installation or build fails | Inspect the failure in `:Lazy`, fix its cause and retry. |

## Features

- **Themes:** Newpaper Light is the default. GitHub Light variants are available
  through `,ft` or `:colorscheme`.
- **Language support:** native Neovim LSP and nvim-cmp completion with LSP, buffer
  and path sources. Snippet expansion uses Neovim's native engine.
- **Navigation:** neo-tree is the only file explorer; Telescope provides file,
  text, buffer and theme selection.
- **Editing and visibility:** Comment.nvim, Gitsigns, Satellite's scrollbar,
  indentation guides, reference highlighting and nvim-notify.

## Where to edit

| Change | File |
| --- | --- |
| Options and native statusline | `lua/config/options.lua` |
| Core keys and personal tab/window gestures | `lua/config/keymaps.lua` |
| Language servers, formatting and LSP keys | `lua/config/lsp.lua` |
| Themes | `lua/plugins/themes.lua` |
| Explorer and search | `lua/plugins/neo-tree.lua`, `lua/plugins/telescope.lua` |
| Completion, comments, Git and visual plugins | Corresponding declaration under `lua/plugins/` |

## Additional tools

| Tool | Preparation and fallback |
| --- | --- |
| Telescope live grep | Install ripgrep. |
| Telescope native fzf sorter | With a C compiler and Make, run `make` in the installed `telescope-fzf-native.nvim` directory. Without its built library, Telescope uses the ordinary sorter. |
| Tree-sitter parsers | Install desired parsers explicitly with `:TSInstall`; missing parsers leave ordinary editing available. Tree-sitter indentation is disabled. |

### Language tools

Install language servers separately. The config looks on `PATH`, then in
`mason/bin` under Neovim's data directory. It reuses those binaries without loading
Mason or installing tools. A missing executable leaves its service disabled.

| Language | Executable / role |
| --- | --- |
| Python | `pyrefly lsp` for types; `ruff server` for diagnostics and formatting |
| Lua | `lua-language-server`, configured for LuaJIT and Neovim's `vim` global |
| Shell | `bash-language-server start` |
| C / C++ / Objective-C | `clangd` |
| Rust | `rust-analyzer` |
| TOML | `taplo lsp stdio` |
| Markdown | `marksman server` |

Use `:checkhealth vim.lsp` to inspect connections. Python formatting selects
Ruff, and Ruff hover is disabled so it does not compete with Pyrefly. Formatting
is explicit, not automatic on save; Lua server formatting remains disabled.
Use each server's project configuration and check its runtime requirements.

## Keymaps

The leader is comma. Colemak uses `h/n/e/i` for left/down/up/right, `u` for
insertion, `l/L` for Undo/Redo, and `k/K` for next/previous search. See the
[keymap policy](keymaps.md#vim-and-neovim) for display-line movement, operator
motions and literal input.

Find the relevant file in [Where to edit](#where-to-edit). Colemak mappings are
fixed, not an alphabet-wide translation. Buffer-local LSP keys load on `LspAttach`,
after Neovim's defaults: `E` opens hover when supported, and `K` retains previous
search.

Neo-tree's `n/e` navigation and `i/u` open/details cycle applies to its filesystem,
buffer and Git sources. Telescope uses `n/e` in Normal mode; Insert-mode queries
stay literal, and the displaced list-bottom action is on `I`.

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

Run these checks from the checkout root.

### Setup checks

Test explicit setup and failure/retry behavior without network access:

```sh
sh tests/nvim/run-setup.sh
```

The base tests need Neovim. Git and an existing lazy.nvim checkout enable a second
tier for native installation, lockfile selection and existing-checkout preservation;
otherwise that tier skips. Use `NVIM` to select the executable and `LAZY` for a
cached manager.

### Plugin integration

Use an existing plugin cache; the runner borrows it without installation and
creates a temporary home, all four XDG directories and a fixture Git repository:

```sh
sh tests/nvim/run-keymaps.sh
```

Pass another cache as the first argument, or set `KEYMAP_TEST_CONFIG` to a linked
deployment's `.config/nvim` instead of the default repository source. Missing
Neovim, Git or neo-tree exits with code 77; other incomplete caches fail. Checks
cover plugin buffers, picker input, completion, an LSP fixture, comments, themes
and statusline, not every external language server.

### Core-only check

For core editing with no manager/plugins, use an empty home and data directory:

```sh
root=$PWD
scratch=$(mktemp -d)
env -i PATH="$PATH" HOME="$scratch" TMPDIR="$scratch" \
  XDG_CONFIG_HOME="$scratch/config" XDG_DATA_HOME="$scratch/data" \
  XDG_CACHE_HOME="$scratch/cache" XDG_STATE_HOME="$scratch/state" \
  KEYMAP_TEST_CONFIG="$root/config/nvim" \
  nvim --headless -u NONE -i NONE -l "$root/tests/nvim/core.lua"
rm -rf "$scratch"
```

These temporary paths do not isolate OS credential services or arbitrary plugin
effects. The declared profile has no authenticated integration; review added
plugins before running them.
