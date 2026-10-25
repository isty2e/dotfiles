# Neovim configuration

Plain Neovim with explicitly selected plugins managed by lazy.nvim. This is not
an AstroNvim or LazyVim profile. It requires Neovim 0.11+, Git, and a terminal with
true-color support. A Nerd Font is optional for file icons. Telescope live grep
requires ripgrep; its native fzf sorter additionally needs a C compiler and Make.

The canonical source is `home/dot_config/nvim/` in this dotfiles repository.
Paths below are relative to that directory unless stated otherwise. The former
[standalone repository](https://github.com/isty2e/dotfiles.nvim) is retained for
history, not as a second source to synchronize. Vim still has its independent
`home/dot_vimrc` entrypoint.

## Install and update

Place the contents of `home/dot_config/nvim/` at Neovim's configuration directory,
normally `~/.config/nvim`, through the reviewed chezmoi procedure in
[setup.md](../setup.md#chezmoi-placement). Do not clone the whole dotfiles repository
there. Without chezmoi, copy that directory's contents into an empty configuration
directory after preserving any existing target.

An existing `~/.config/nvim` may itself be a Git working tree. Before an approved
live handoff, preserve it outside the destination rather than applying into it
and leaving two apparent source owners. Do not delete its `.git` metadata or
plugin data as an installation step. Plugin data, editor state and caches are
separate from the configuration; selecting a different configuration does not
isolate them. This source consolidation does not perform that live handoff.

Install lazy.nvim explicitly if it is not already present:

```sh
git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim"
```

Start Neovim and run `:Lazy install` to acquire the declared plugins. This is an
explicit network/install action and executes third-party plugin code. Ordinary
startup does not clone lazy.nvim, install missing plugins, check for updates,
install language servers or download Tree-sitter parsers. Without lazy.nvim,
options and core editing maps still load, with a warning; that is not the full
plugin profile.

`lazy-lock.json` records the selected plugin revisions. Use `:Lazy restore` to
return installed plugins to those revisions. Review and commit lockfile changes
after an intentional `:Lazy update`. Tree-sitter's legacy API is also pinned in
its declaration; migrating to its newer API is a separate change.

For the native Telescope sorter, run `make` in the installed
`telescope-fzf-native.nvim` directory. Without its built library, Telescope uses
its ordinary sorter. Install desired parsers explicitly with `:TSInstall`;
missing parsers leave ordinary editing available. Tree-sitter indentation is
disabled.

## Features and their owners

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

This selected profile does not include AI/authenticated completion, a debugger,
an embedded-terminal plugin, session restoration or a Markdown-renderer bundle.
Those are not needed for its chosen feature set; they can be considered
individually if a concrete workflow needs them. Installing this configuration
does not delete old plugin caches or migrate another profile's state.

## Language tools

Install language servers separately. Configuration resolves executable names
from `PATH`, then reuses binaries already present under Neovim's data directory
at `mason/bin`; it does not load Mason or provision tools. An unavailable
executable leaves that service disabled rather than selecting another provider.

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
Project configuration and installed server/runtime compatibility remain the
language tools' responsibility.

## Keymaps

The leader is comma. Modal edits use `h/n/e/i` for left/down/up/right, `j` for
word end, `u` for insertion, `l/L` for Undo/Redo, and `k/K` for next/previous
search match. Normal and Visual vertical navigation follows display lines;
`gj/gk` retain logical lines. Operator motions use logical lines, so `dn` remains
linewise. Inner text objects use `u`, as in `duw`; following selectors stay
native. Inserted text, Select input, queries, character arguments and
register/mark names are not transposed.

Keep maps at the owner that can enforce them:

- `lua/config/keymaps.lua`: mode-specific core cycles and existing personal tab
  and window gestures. No full-alphabet transformer or runtime layout toggle.
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

The integration runner uses a temporary home, all four XDG directories and a
fixture Git repository. It borrows an existing selected-plugin cache and never
installs plugins:

```sh
sh tests/nvim/run-keymaps.sh
```

Pass the cache directory as the first argument when it is elsewhere. To exercise
an isolated chezmoi result, set `KEYMAP_TEST_CONFIG` to its `.config/nvim` directory;
the default is this repository's `home/dot_config/nvim`. Missing
Neovim, Git or the neo-tree cache produces exit code 77; other incomplete caches
surface integration failures. The runner exercises real plugin buffers,
picker input, completion, native LSP attachment with an
in-process protocol fixture, comments, themes and statusline rendering. It does
not establish compatibility with every external language server.

For core editing with no manager/plugins, use an empty home and data directory:

```sh
root=$PWD
scratch=$(mktemp -d)
env -i PATH="$PATH" HOME="$scratch" TMPDIR="$scratch" \
  XDG_CONFIG_HOME="$scratch/config" XDG_DATA_HOME="$scratch/data" \
  XDG_CACHE_HOME="$scratch/cache" XDG_STATE_HOME="$scratch/state" \
  KEYMAP_TEST_CONFIG="$root/home/dot_config/nvim" \
  nvim --headless -u NONE -i NONE -l "$root/tests/nvim/core.lua"
rm -rf "$scratch"
```

Temporary paths isolate configuration and file state, not OS credential services
or arbitrary effects of third-party code. The declared profile has no
authenticated integration; review added plugins before running them.
