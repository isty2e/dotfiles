# Colemak keymap policy

These tables define target bindings. Execution plans and verification procedures are tracked in Kata.

Native editor files own bindings; chezmoi handles placement, not semantic repair. Keep rendering/placement separate from fetching defaults, installing packages, and handling secrets.

## Shared contract

| Intention | Keys | Meaning |
| --- | --- | --- |
| Left / down / up / right | `h / n / e / i` | Cursor navigation follows display lines; operator line motions retain logical lines |
| Previous word / next word / word end | `b / w / j` | Native word boundaries |
| Insert / return to command mode | `u / Esc` | Ordinary modal text editing |
| Undo / redo | `l / L` | `L` is redo, not undo-line |
| Search / next result / previous result | `/ / k / K` | Query text remains literal |
| Window focus | `Ctrl-w` then `h/n/e/i` | Distinct from tabs, buffers, and search results |

Retain a separate logical-line route. Helix's `g n / g e` is not a universal prefix requirement.

Zed targets native `h/j/k/l` directional bindings by input role, regardless of their source file or whether they require Vim mode. Preserve specialized navigation operations rather than replacing them with generic cursor movement. Cycle tables describe configured overrides; editing, history, search, and literal-input rules remain scoped to their native input roles.

## Select bindings by intent

1. Select by effective input role, action **and arguments**, operator/UI state, and native precedence—not by a key glyph or mode label alone.
2. Preserve inserted text, queries, literal character arguments, and register/mark names. Do not lift a letter permutation into every modifier or input namespace.
3. Close substitutions cyclically: each new key performs its source key's original operation, including displaced actions, aliases, complete subtrees, and known empty slots.
4. Keep native editing models and deliberate editor-specific spellings. Old manual bindings are evidence, not exceptions to this policy. Leave unrelated native bindings unchanged; Helix keybinding overrides are limited to cycle slots and their prefix containers.

Same-key examples include insertion versus inner-object selection and completion versus signature navigation. Even `vim::Down` changes meaning with `display_lines`. Different contexts must not be merged merely to shorten the file.

## Cycle notation

An arrow means **original action's key → its new key**. Every affected binding moves once; an inherited old action must not leak into a moved vacancy. Deliberate action removal is a separate explicit decision, not an unexplained test exception.

### Helix 25.07.1

| Native scope | Intended cycles |
| --- | --- |
| Normal and Select navigation/search | `j → n → k → e → j` |
| Normal and Select insertion/undo/right | `i → u → l → i` |
| Normal and Select long-word/join/search/keep | `J → N → K → E → J` |
| Normal and Select line insertion/redo/vacancy | `I → U → L → I` |
| Normal and Select `g` | `j → n → k → e → j`; `i ↔ l` |
| Normal and Select `Ctrl-w` / `Space w` focus/menu | `j → n → k → e → j`; `l ↔ i` |
| Normal and Select `Ctrl-w` / `Space w` swaps/vacancies | `J → N → K → E → J`; `L ↔ I` |

Consequences of these cycles:
- Root `E` receives `keep_selections`; long-word-end remains on `J`.
- Both window prefixes use the same bindings: `n/e/i/h` focus down/up/right/left.
- `Ctrl-w k` and `Space w k` receive the complete new-scratch-split subtree: `s/v/C-s/C-v`.
- Under both prefixes, `j/l/J/K/L` are vacancies after relocation, not inherited focus/swap aliases.
- Root `U` receives `insert_at_line_start` in both modes; `I` receives the native vacancy.

Baseline: [25.07.1 defaults](https://github.com/helix-editor/helix/blob/25.07.1/helix-term/src/keymap/default.rs). Select inherits Normal except for its declared overrides. [Native trie merge](https://github.com/helix-editor/helix/blob/25.07.1/helix-term/src/keymap.rs) recursively merges branches but replaces a branch when overridden by a leaf.

### Zed navigation: source baseline 1.25.3

| Native scope | Cycles |
| --- | --- |
| ProjectPanel and OutlinePanel, when not editing | `j → n → k → e → j`; `l ↔ i` |
| Git Changes/History lists, excluding branch/repository selectors | `j → n → k → e → j` |
| Git Changes tree under the same selector exclusions | `i → u → l → i` |
| GitGraph outside its search bar; FileHistoryView | `j → n → k → e → j` |
| Settings navigation outside search; non-Editor ThreadsSidebar | `j → n → k → e → j`; `l ↔ i` |
| Notebook command mode | `j → n → k → e → j`; `i ↔ u` |
| Notebook/ThreadsSidebar child Editors in Vim Normal outside menus | `j → n → k → e → j`, preserving their specialized cell/sidebar motions |
| Prompt selection, separately scoped for macOS and Linux | `l ↔ i` |

Keep native left/collapse bindings. Preserve each scope's native operation and arguments, including Vim menu actions and specialized Editor motions. Prompt retains its platform's native key-equivalent setting. Vacated bindings are disabled with `null`; unrelated aliases remain inherited. Rename/search/picker input is not translated.

The Zed fixture checks configured bindings through selected overlapping source/user layers and candidate-rule collection; it does not reimplement Zed's context evaluator. Zed owns runtime key dispatch. Profile verification checks native contexts, action arguments and configured cycles, trusting the editor to execute its keymap contract. Manual GUI checks are optional troubleshooting for a concrete mismatch, not a completion prerequisite. Copied edit-prediction defaults are inherited from Zed rather than maintained here.

### Zed Vim/Helix modal editing: source baseline 1.25.3

| Native input role | Cycles |
| --- | --- |
| Vim Normal and Visual cursor motions | `j → g j → n → k → g k → e → j` |
| Vim operator-pending motions | `j → n → k → e → j`; native display-line `g j/g k` remain unchanged |
| Helix Normal outside the search bar | `j → n → k → e → j`; `g j → g n → g k → g e → g j` |
| Helix Select and search-bar Normal | `j → g n → g k → e → j`; `k → g e → g j → n → k` |
| Insertion/inner object, undo/case/operator command, right | `i → u → l → i` |
| Long-word end, join/vacancy, previous search, hover | `J → N → K → E → J` |
| Vim Normal line insertion/history/screen bottom | `I → U → Ctrl-r → L → I` |
| Visual, pending operators and Helix uppercase roles | `I → U → L → I` |
| Helix implementation/staging/end of line | `g i → g u → g l → g i` |
| Ctrl-w focus/splits, including Ctrl-modified aliases | `j → n → k → e → j`; `l ↔ i` |
| Ctrl-w pane movement | `J → N → K → E → J`; `L ↔ I` |
| Helix Space-w focus | `j → n → k → e → j`; `l ↔ i` |

Normal history uses `l/L` for Undo/Redo; Vim Visual instead preserves native lower/uppercase conversion there. Helix retains its native Ctrl-r redo alias. Its Select-mode `I` vacancy moves to `U`, rather than inventing an insertion command absent from that native role. Ctrl-w `k` and Ctrl-w Ctrl-k retain the displaced new-file split operation.

Completion and signature navigation inherit native Ctrl-n, while Ctrl-k keeps digraph input. Helix hover inherits Space-k. The earlier manual case-conversion aliases are not retained: `g u` is implementation navigation in the configured cycle, and unchanged `g Shift-u` is native unstaging. The former Insert Ctrl-x Ctrl-i/Ctrl-x Ctrl-j aliases are not defined here; they are not redundant copies of current defaults.

Native object selectors, literal character arguments, register names and mode-specific insert/waiting/replace control namespaces are not transposed. The generic movement scope excludes object-selection states; `u` selects the inner object before its native selector. Unrelated modal command-alphabet remaps are removed in favor of native bindings. Personal comma-tab and existing completion-popup gestures remain unchanged.

Specialized notebook/sidebar Editors keep cell/sidebar motion on `n/e` and retain their native display-line `g j/g k` aliases. Ordinary Vim logical motion uses `g j/g k`; ordinary Helix logical motion uses `g n/g e`. This modal rewrite does not change menu-owned input or non-modal document editing.

### Vim and Neovim

Normal and Visual cursor movement uses display lines, including counts; `g j/g k`
retain logical-line movement. Operator-pending `n/e` uses logical lines so `dn`
stays linewise. Insert, Select, command-line and terminal input are not transposed.

| Native operations / context | Cycle |
| --- | --- |
| Normal/Visual logical/display movement, search, word end | `j → g j → n → k → g k → e → j` |
| Operator logical movement, search, word end | `j → n → k → e → j` |
| Normal insertion/undo/right; Visual inner-object/lowercase/right | `i → u → l → i` |
| Join, previous search, keyword operation, long-word end | `J → N → K → E → J` |
| Normal first-nonblank insertion, undo-line, redo, screen bottom | `I → U → Ctrl-r → L → I` |
| Visual block insertion, uppercase, screen bottom | `I → U → L → I` |
| Operator inner-object/right and screen-bottom slots | `i → u → l → i`; `I → U → L → I` |
| Window down/new split/up and displaced blank | `Ctrl-w j → n → k → e → j` |
| Window right/include-file; far-right/include-definition | `Ctrl-w i ↔ l`; `Ctrl-w I ↔ L` |
| Window bottom/top and displaced blanks | `Ctrl-w J → N → K → E → J` |

Window lowercase Ctrl-key alternatives follow the same window-local cycles.
Vacant Normal/Visual window slots are no-ops; vacant operator slots cancel the
pending operator. Unrelated Ctrl shortcuts and native command spellings are not
transposed. Existing personal tab, completion and terminal gestures stay separate.

In `home/private_dot_config/nvim/`, `lua/config/keymaps.lua` owns general mode maps and
`lua/config/lsp.lua` owns
attached-buffer hover on `E` and search on `K`, and each plugin owns its local interaction. Neo-tree
retains native parent/child handlers, moves file details to `u` in its filesystem,
buffer and Git sources, and uses `n/e` in its normal-mode filter. Telescope uses
`n/e` for normal-mode selection and `I` for its displaced list-bottom action.
Insert-mode queries stay literal; unrelated command letters use plugin defaults.

NERDTree retains its native commands with local displacements: `j → n → k → e → j`,
`i → u → l → i`, `J → N → K → E → J`, and `I → U → Ctrl-r → L → I`.
Its preview split remains `g i` rather than being derived from the new split key.

### Text-object spellings

Use `u` for Vim, Neovim and Zed inner-object selection (`duw`) and retain Helix
`m i`. Following selectors remain native. The Helix override-scope check protects
`m i` by leaving its native bindings untouched. Zed source-data tests distinguish
outer object selection from native selectors; Zed owns execution of those bindings.

## Deferred and out-of-scope choices

| Item | Disposition / owner | Revisit condition |
| --- | --- | --- |
| Runtime Colemak/QWERTY toggle | Out of scope; user | A real switching workflow is requested |
| Identical object selectors across editors | Not required; user | Explicitly choose common spellings |
| Universal transformer / key-generating template layer | Deferred; maintainer | Repeated native maintenance shows a stable useful abstraction |
| Uniform command-alphabet translation | Not adopted; user | Explicitly accept its command-spelling changes |
| chezmoi source-tree migration | Separate work; maintainer/user | Authorize filesystem handoff after independent keymap repair |
| Zed version-mismatch test / update watcher | Not adopted; user | An automatic update-notification workflow is requested |
| Scheduled repair / unattended apply / GUI automation | Not authorized; user | Approve the operating and verification model |
| Neovim live deployment / old-repository archival | Separate work; user | Source consolidation does not authorize replacing home targets or archiving/deleting the old repository |
