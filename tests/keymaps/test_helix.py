"""Preserve native Helix operations across the configured Colemak cycles.

Requires Python 3.11 or newer; no Helix executable is needed.
"""

import tomllib
import unittest
from collections.abc import Mapping
from copy import deepcopy
from pathlib import Path
from typing import TypeAlias, cast

Binding: TypeAlias = str | list[str] | dict[str, "Binding"]
Keymap: TypeAlias = dict[str, Binding]


def _read_keymaps(path: Path) -> dict[str, Keymap]:
    with path.open("rb") as stream:
        return cast(dict[str, Keymap], tomllib.load(stream)["keys"])


def _merge_keymaps(base: Keymap, overrides: Mapping[str, Binding]) -> Keymap:
    # Native merge contract: helix-term/src/keymap.rs in Helix 25.07.1.
    merged = deepcopy(base)
    for key, value in overrides.items():
        inherited = merged.get(key)
        if isinstance(inherited, dict) and isinstance(value, dict):
            merged[key] = _merge_keymaps(inherited, value)
        else:
            merged[key] = deepcopy(value)

    return merged


class HelixCyclesTest(unittest.TestCase):
    def test_native_cycles_preserve_every_source_binding(self) -> None:
        test_dir = Path(__file__).resolve().parent
        native = _read_keymaps(test_dir / "fixtures" / "helix-25.07.1.toml")
        overrides = _read_keymaps(
            test_dir.parents[1] / "home/private_dot_config/helix/config.toml"
        )
        # Both native window prefixes contain these same selected bindings.
        native["normal"]["space"] = {"w": deepcopy(native["normal"]["C-w"])}
        native["select"] = _merge_keymaps(native["normal"], native["select"])

        window_cycles = (
            ("h",),
            ("H",),
            ("j", "n", "k", "e"),
            ("l", "i"),
            ("J", "N", "K", "E"),
            ("L", "I"),
        )
        cycles_by_prefix: dict[tuple[str, ...], tuple[tuple[str, ...], ...]] = {
            (): (
                ("h",),
                ("j", "n", "k", "e"),
                ("i", "u", "l"),
                ("J", "N", "K", "E"),
                ("I", "U", "L"),
            ),
            ("g",): (("j", "n", "k", "e"), ("i", "l")),
            ("C-w",): window_cycles,
            ("space",): (),
            ("space", "w"): window_cycles,
        }

        self.assertLessEqual(
            {mode for mode, bindings in overrides.items() if bindings}, native.keys()
        )

        for mode in ("normal", "select"):
            effective = _merge_keymaps(native[mode], overrides[mode])
            for prefix, cycles in cycles_by_prefix.items():
                before = native[mode]
                after = effective
                configured = overrides[mode]
                for key in prefix:
                    child = configured.get(key, {})
                    self.assertIsInstance(child, dict)
                    configured = cast(Keymap, child)
                    before = cast(Keymap, before[key])
                    after = cast(Keymap, after[key])

                allowed = {key for cycle in cycles for key in cycle}
                allowed.update(
                    path[len(prefix)]
                    for path in cycles_by_prefix
                    if len(path) > len(prefix) and path[: len(prefix)] == prefix
                )
                with self.subTest(mode=mode, prefix=prefix, check="override_scope"):
                    self.assertLessEqual(configured.keys(), allowed)

                for cycle in cycles:
                    for source, destination in zip(
                        cycle, cycle[1:] + cycle[:1], strict=True
                    ):
                        with self.subTest(
                            mode=mode,
                            prefix=prefix,
                            source=source,
                            destination=destination,
                        ):
                            self.assertEqual(after[destination], before[source])

    def test_native_merge_preserves_children_and_replaces_a_branch_with_an_action(
        self,
    ) -> None:
        base: Keymap = {"n": {"s": "hsplit_new", "v": "vsplit_new"}}

        self.assertEqual(
            _merge_keymaps(base, {"n": {"s": "no_op"}}),
            {"n": {"s": "no_op", "v": "vsplit_new"}},
        )
        self.assertEqual(
            _merge_keymaps(base, {"n": "jump_view_down"}), {"n": "jump_view_down"}
        )
        self.assertEqual(base, {"n": {"s": "hsplit_new", "v": "vsplit_new"}})


if __name__ == "__main__":
    unittest.main()
