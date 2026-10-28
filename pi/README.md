# Pi PaperColor themes

Five JSON themes for [Pi](https://pi.dev), adapted from PaperColor's Vim, Zed and
VS Code Redux variants. Copy or link the files; no build or package is needed.

| Theme | Terminal background | Terminal foreground |
| --- | --- | --- |
| `papercolor-original-light` | `#eeeeee` | `#444444` |
| `papercolor-original-dark` | `#1c1c1c` | `#d0d0d0` |
| `papercolor-zed-light` | `#eeeeee` | `#444444` |
| `papercolor-zed-dark` | `#1c1c1c` | `#d0d0d0` |
| `papercolor-redux-light` | `#f3f3f3` | `#444444` |

## Install

From the checkout root, copy the themes into Pi's user theme directory.

If a destination is already a symlink, keep it or move it aside before making an
independent copy. `cp -i` asks before overwriting existing files.

```sh
mkdir -p "$HOME/.pi/agent/themes"
cp -i pi/themes/*.json "$HOME/.pi/agent/themes/"
```

To edit themes directly in the checkout, use links instead:

```sh
mkdir -p "$HOME/.pi/agent/themes"
for theme in "$PWD"/pi/themes/*.json; do
  ln -s "$theme" "$HOME/.pi/agent/themes/$(basename "$theme")"
done
```

Keep the checkout in place while using links. `ln` reports a conflict rather
than replacing an existing destination. Keep that file or move it aside first.

Run `/reload` in Pi, then choose a theme in `/settings`. To set the initial theme
for one invocation without changing the saved setting:

```sh
pi --use-theme papercolor-original-light
```

Pi also supports light/dark pairing:

```sh
pi --use-theme papercolor-original-light/papercolor-original-dark
```

Set the terminal background and foreground to the table's values. Pi colors text
and panels, not the whole terminal canvas; light/dark selection does not recolor
the terminal. Use truecolor for this palette. Pi approximates it on 256-color
terminals.

## Variants and adaptations

- **Original** uses the Vim palette and its generic syntax and Markdown mappings.
  Markdown headings and links are pink in Light and lime in Dark.
- **Zed** shares Original's base palette and code colors. It uses Zed's elevated
  surfaces, softer selection/search colors, gray headings and blue links.
- **Redux Light** uses a brighter base, navy types, neutral variables and
  punctuation, pale-blue selection and purple links. Upstream has no Redux Dark
  palette, so this set contains only Redux Light.

Pending and successful tool panels share a neutral background, rather than
tinting successful output green. Error panels use an 8% negative-color blend.
Custom panels use a 6% purple blend, except for Redux's native quote background.
Dark error and removed-line text use upstream's brighter pink `#ff5faf` instead
of `#af005f`.

Selection and search overlays are flattened to opaque RGB. Pi has no selected-text
foreground token; Original uses the popup-menu surface, Zed uses composited
selected-element/search colors, and Redux uses its list-focus background.
Unhighlighted code and quote bodies use the main foreground. Explicit HTML export
backgrounds are included.

Pi has fewer syntax roles than the source editors. These themes do not reproduce
language-specific overrides, font styles or exact editor rendering. Muted and
accent colors retain upstream values; some do not meet WCAG text contrast
thresholds. Edit the JSON files in [`themes/`](themes/) directly; there is no
generator.

## Sources and licenses

These are adaptations, not official upstream Pi releases. All three sources are
MIT-licensed. Their full notices are in [`licenses/`](licenses/); retain them when
redistributing these themes.

| Source | Pinned palette/mapping revision |
| --- | --- |
| [NLKNguyen/papercolor-theme](https://github.com/NLKNguyen/papercolor-theme) | [`0cfe64f`](https://github.com/NLKNguyen/papercolor-theme/blob/0cfe64ffb24c21a6101b5f994ca342a74c977aef/colors/PaperColor.vim) |
| [emirror-de/papercolor-zed](https://github.com/emirror-de/papercolor-zed) | [`cf6bafb`](https://github.com/emirror-de/papercolor-zed/blob/cf6bafb430bf6ca6cedc711dd3a9abbf179a1451/themes/papercolor.json) |
| [mrworkman/papercolor-vscode-redux](https://github.com/mrworkman/papercolor-vscode-redux) | [`52ad46f`](https://github.com/mrworkman/papercolor-vscode-redux/blob/52ad46f0bf5a9188d55665c58a0aeaa4b37c2be9/src/themes/papercolor.yaml) |
