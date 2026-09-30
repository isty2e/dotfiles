# Pi PaperColor themes

Five static JSON themes for [Pi](https://pi.dev), adapted from PaperColor's Vim,
Zed and VS Code Redux variants. No package installation or build step is needed.

| Theme | Terminal background | Terminal foreground |
| --- | --- | --- |
| `papercolor-original-light` | `#eeeeee` | `#444444` |
| `papercolor-original-dark` | `#1c1c1c` | `#d0d0d0` |
| `papercolor-zed-light` | `#eeeeee` | `#444444` |
| `papercolor-zed-dark` | `#1c1c1c` | `#d0d0d0` |
| `papercolor-redux-light` | `#f3f3f3` | `#444444` |

## Install

From the root of this dotfiles checkout, link the theme files into Pi's user theme
directory:

```sh
mkdir -p "$HOME/.pi/agent/themes"
for theme in "$PWD"/pi/themes/*.json; do
  ln -s "$theme" "$HOME/.pi/agent/themes/$(basename "$theme")"
done
```

Keep the checkout in place. Existing destination files are not replaced: `ln`
reports a conflict. If you already copied a theme there, keep that copy or move it
aside before linking the same name.

To use copies instead:

```sh
mkdir -p "$HOME/.pi/agent/themes"
cp -i pi/themes/*.json "$HOME/.pi/agent/themes/"
```

Run `/reload` in Pi, then choose a theme in `/settings`. To select the initial
theme for one invocation without changing the saved setting:

```sh
pi --use-theme papercolor-original-light
```

Pi also supports light/dark pairing:

```sh
pi --use-theme papercolor-original-light/papercolor-original-dark
```

Set your terminal's background and foreground to the values in the table. Pi
colors text and individual panels, not the whole terminal canvas. Automatic
light/dark selection does not recolor the terminal. Use truecolor for the intended
palette; 256-color terminals receive approximations.

## Variants and adaptations

- **Original** uses the Vim palette and its generic syntax and Markdown mappings.
  Markdown headings and links are pink in Light and lime in Dark.
- **Zed** shares Original's base palette and code colors. It uses Zed's elevated
  surfaces, softer selection/search colors, gray headings and blue links.
- **Redux Light** uses a brighter base, navy types, neutral variables and
  punctuation, pale-blue selection and purple links. There is no Redux Dark
  upstream, so no speculative Dark variant is included here.

Pending and successful tool panels share a neutral surface: ordinary command,
code and diff output is not tinted green on success. Error panels retain an 8%
negative-color blend. Custom panels use a 6% purple blend, except Redux's native
quote background. Dark error and removed-line text use the brighter upstream
pink `#ff5faf` instead of `#af005f`.

Selection and search overlays are flattened to opaque RGB. Pi has no selected-text
foreground token; Original uses the popup-menu surface, Zed uses composited
selected-element/search colors, and Redux uses its list-focus background.
Unhighlighted code and quote bodies use the main foreground. Explicit HTML export
backgrounds are included.

Pi has fewer syntax roles than the source editors. Language-specific overrides,
font styles and exact editor rendering parity are out of scope. Muted and accent
colors retain upstream values; not every token meets WCAG text contrast thresholds.
The JSON files in [`themes/`](themes/) are directly editable; there is no generator.

## Sources and licenses

These are adaptations, not official upstream Pi releases. All three sources are
MIT-licensed. Their full notices are in [`licenses/`](licenses/); retain them when
redistributing these themes.

| Source | Pinned palette/mapping revision |
| --- | --- |
| [NLKNguyen/papercolor-theme](https://github.com/NLKNguyen/papercolor-theme) | [`0cfe64f`](https://github.com/NLKNguyen/papercolor-theme/blob/0cfe64ffb24c21a6101b5f994ca342a74c977aef/colors/PaperColor.vim) |
| [emirror-de/papercolor-zed](https://github.com/emirror-de/papercolor-zed) | [`cf6bafb`](https://github.com/emirror-de/papercolor-zed/blob/cf6bafb430bf6ca6cedc711dd3a9abbf179a1451/themes/papercolor.json) |
| [mrworkman/papercolor-vscode-redux](https://github.com/mrworkman/papercolor-vscode-redux) | [`52ad46f`](https://github.com/mrworkman/papercolor-vscode-redux/blob/52ad46f0bf5a9188d55665c58a0aeaa4b37c2be9/src/themes/papercolor.yaml) |
