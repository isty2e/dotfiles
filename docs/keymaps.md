# Colemak keymap policy

These tables define target bindings. Execution plans and verification procedures are tracked in Kata.

Native editor files own bindings; chezmoi handles placement, not semantic repair. Keep rendering/placement separate from fetching defaults, installing packages, and handling secrets.

## Shared contract

| Intention | Keys | Meaning |
| --- | --- | --- |
| Left / down / up / right | `h / n / e / i` | Default vertical navigation follows display lines |
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

The Zed fixture checks these navigation definitions, selected overlapping source/user layers, and candidate-rule collection. It is not a context evaluator or verification of other editor-mode overrides or actual runtime dispatch. Copied edit-prediction defaults are inherited from Zed rather than maintained here.

### Vim / Neovim / Zed Vim-normal references

These are reference cycles, not a completed inventory for every mode or context.

| Native operations | Reference cycle |
| --- | --- |
| Logical/display movement, search, word end | `j → g j → n → k → g k → e → j` |
| Insertion, undo, right | `i → u → l → i` |
| Join, previous search, keyword operation, long-word end | `J → N → K → E → J` |
| First-nonblank insertion, undo-line, redo, screen bottom | `I → U → Ctrl-r → L → I` |

Resolve each native action, payload, and effective context before adopting a reference cycle. Operator/object input is not automatically a copy of Normal navigation.

### Text-object spellings

Use `u` for Zed inner-object selection (`duw`) and retain Helix `m i`. The Helix override-scope check protects `m i` by leaving its native bindings untouched. Zed dispatch verification remains follow-up work; its chosen spelling is policy, not a claim of existing test coverage.

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
| Neovim repository move / plugin overhaul | Separate work; user | An independent ownership or tooling decision |
