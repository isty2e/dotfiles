"""Check native navigation, modal input roles and read-only comparisons.

Requires Python 3.11+ and tests/keymaps/requirements.txt, not a Zed executable.
"""

import json
import subprocess
import sys
import tempfile
import unittest
from collections.abc import Sequence
from pathlib import Path
from typing import NotRequired, TypedDict, cast

import json5

if __package__:
    from . import compare_zed as _comparison
else:
    import compare_zed as _comparison


class _RuleData(TypedDict):
    source: str
    metadata: dict[str, _comparison.JsonValue]
    keystrokes: list[str]
    action: _comparison.JsonValue
    block: int
    binding: int


class _CycleData(TypedDict):
    cycles: list[list[str]]
    vacancies: list[str]
    preserved_sequences: NotRequired[list[list[str]]]


class _ProfileData(_CycleData):
    metadata: dict[str, _comparison.JsonValue]
    native_metadata: NotRequired[dict[str, _comparison.JsonValue]]
    base_metadata: NotRequired[list[dict[str, _comparison.JsonValue]]]
    user_base_metadata: NotRequired[list[dict[str, _comparison.JsonValue]]]
    overlap_variants: NotRequired[list[list[dict[str, _comparison.JsonValue]]]]
    user_overlap_variants: NotRequired[list[list[dict[str, _comparison.JsonValue]]]]


class _ModalCase(_CycleData):
    name: str
    native_layers: list[dict[str, _comparison.JsonValue]]
    user_layers: list[dict[str, _comparison.JsonValue]]


class _SlotData(TypedDict):
    metadata: dict[str, _comparison.JsonValue]
    keystrokes: list[str]


class _Fixture(TypedDict):
    upstream_ref: str
    sources: list[str]
    tracked_sequences: list[list[str]]
    native_rules: list[_RuleData]
    profiles: list[_ProfileData]
    modal_cases: list[_ModalCase]
    modal_slots: list[_SlotData]
    other_editor_slots: list[_SlotData]


def _project_bindings(
    rules: Sequence[_comparison.Binding],
    layers: Sequence[dict[str, _comparison.JsonValue]],
) -> dict[tuple[str, ...], _comparison.JsonValue]:
    return {rule.keystrokes: rule.action for rule in rules if rule.metadata in layers}


class ZedNavigationTest(unittest.TestCase):
    def setUp(self) -> None:
        test_dir = Path(__file__).resolve().parent
        self.fixture = cast(
            _Fixture, json.loads((test_dir / "fixtures/zed-1.25.3.json").read_text())
        )
        self.native = [
            _comparison.Binding(
                row["source"],
                row["metadata"],
                tuple(row["keystrokes"]),
                row["action"],
                row["block"],
                row["binding"],
            )
            for row in self.fixture["native_rules"]
        ]
        keymap = cast(
            _comparison.Keymap,
            json5.loads(
                (
                    test_dir.parents[1] / "home/private_dot_config/zed/keymap.json"
                ).read_text()
            ),
        )
        self.user = _comparison.collect_bindings([("user", keymap)])

    def _assert_cycles(
        self,
        spec: _CycleData,
        before: dict[tuple[str, ...], _comparison.JsonValue],
        overrides: dict[tuple[str, ...], _comparison.JsonValue],
    ) -> None:
        for value in spec["vacancies"]:
            key = tuple(value.split())
            self.assertNotIn(key, before)
            before[key] = None
        after = before | overrides
        for cycle in spec["cycles"]:
            for source, destination in zip(cycle, cycle[1:] + cycle[:1], strict=True):
                with self.subTest(source=source, destination=destination):
                    self.assertEqual(
                        after[tuple(destination.split())], before[tuple(source.split())]
                    )
        for sequence in spec.get("preserved_sequences", []):
            with self.subTest(preserved=sequence):
                self.assertEqual(after[tuple(sequence)], before[tuple(sequence)])

    def test_tracking_manifest_matches_all_user_overrides(self) -> None:
        self.assertEqual(
            {tuple(k) for k in self.fixture["tracked_sequences"]},
            {r.keystrokes for r in self.user},
        )

    def test_navigation_cycles_preserve_native_rules_and_vacancies(self) -> None:
        for profile in self.fixture["profiles"]:
            metadata = profile["metadata"]
            native_variants = [[], *profile.get("overlap_variants", [])]
            user_variants = [
                [],
                *profile.get(
                    "user_overlap_variants", profile.get("overlap_variants", [])
                ),
            ]
            for extra, user_extra in zip(native_variants, user_variants, strict=True):
                native_layers = [
                    *profile.get("base_metadata", []),
                    *extra,
                    profile.get("native_metadata", metadata),
                ]
                user_layers = [
                    *profile.get(
                        "user_base_metadata", profile.get("base_metadata", [])
                    ),
                    *user_extra,
                    metadata,
                ]
                with self.subTest(context=metadata, extra=extra):
                    self._assert_cycles(
                        profile,
                        _project_bindings(self.native, native_layers),
                        _project_bindings(self.user, user_layers),
                    )

    def test_modal_cycles_and_native_input_roles(self) -> None:
        for case in self.fixture["modal_cases"]:
            with self.subTest(case=case["name"]):
                self._assert_cycles(
                    case,
                    _project_bindings(self.native, case["native_layers"]),
                    _project_bindings(self.user, case["user_layers"]),
                )

    def test_navigation_footprint_and_other_competing_key_slots(self) -> None:
        watched = tuple(tuple(key) for key in self.fixture["tracked_sequences"])
        outside_slots = [
            (slot["metadata"], tuple(slot["keystrokes"]))
            for slot in self.fixture["other_editor_slots"] + self.fixture["modal_slots"]
        ]
        for rule in self.user:
            context = rule.metadata.get("context", "")
            is_navigation = isinstance(context, str) and any(
                name in context
                for name in (
                    "ProjectPanel",
                    "OutlinePanel",
                    "GitPanel",
                    "GitGraph",
                    "FileHistoryView",
                    "SettingsWindow",
                    "NotebookEditor",
                    "ThreadsSidebar",
                    "Prompt",
                )
            )
            with self.subTest(context=context, key=rule.keystrokes):
                if is_navigation:
                    matches = [
                        p
                        for p in self.fixture["profiles"]
                        if p["metadata"] == rule.metadata
                    ]
                    self.assertEqual(len(matches), 1)
                    allowed = {
                        tuple(key.split())
                        for cycle in matches[0]["cycles"]
                        for key in cycle
                    }
                    allowed.update(
                        tuple(key) for key in matches[0].get("preserved_sequences", [])
                    )
                    self.assertIn(rule.keystrokes, allowed)
                elif rule.relates_to(watched):
                    self.assertIn((rule.metadata, rule.keystrokes), outside_slots)

    def test_prediction_candidate_rules_remain_inherited(self) -> None:
        watched = (("alt-l",),)
        native = [rule for rule in self.native if rule.relates_to(watched)]
        self.assertEqual(
            native + [rule for rule in self.user if rule.relates_to(watched)], native
        )


class ZedCandidateTest(unittest.TestCase):
    def test_argument_and_metadata_scalar_types_are_distinct(self) -> None:
        for field in ("action", "metadata"):
            before = _comparison.Binding(
                "base", {}, ("x",), ["move", {"flag": True}], 0, 0
            )
            after = _comparison.Binding("base", {}, ("x",), ["move", {"flag": 1}], 0, 0)
            if field == "metadata":
                before = _comparison.Binding(
                    "base", {"use_key_equivalents": True}, ("x",), None, 0, 0
                )
                after = _comparison.Binding(
                    "base", {"use_key_equivalents": 1}, ("x",), None, 0, 0
                )
            with self.subTest(field=field):
                self.assertNotEqual(before, after)

    def test_prefix_family_order_metadata_and_arguments_are_preserved(self) -> None:
        blocks: _comparison.Keymap = [
            {
                "context": "Editor",
                "bindings": {
                    "g": "prefix",
                    "g n": "first",
                    "g n x": ["motion", {"display_lines": True}],
                    "g x": "sibling",
                },
            },
            {
                "context": "Editor && waiting",
                "use_key_equivalents": True,
                "bindings": {"g n": None},
            },
        ]
        watched = (("g", "n"),)
        rules = _comparison.collect_bindings([("base", blocks)], watched)
        self.assertEqual(
            [rule.keystrokes for rule in rules],
            [("g",), ("g", "n"), ("g", "n", "x"), ("g", "n")],
        )
        self.assertEqual(rules[-1].metadata["use_key_equivalents"], True)
        self.assertIsNone(rules[-1].action)
        self.assertNotEqual(rules, list(reversed(rules)))

        later: _comparison.Keymap = [
            {"context": "Editor", "bindings": {"g n": "later"}}
        ]
        combined = _comparison.collect_bindings(
            [("z-base", blocks), ("a-user", later)], watched
        )
        self.assertEqual(
            [rule.source for rule in combined], ["z-base"] * 4 + ["a-user"]
        )

        bindings = cast(dict[str, _comparison.JsonValue], blocks[0]["bindings"])
        bindings["g n x"] = ["motion", {"display_lines": False}]
        self.assertNotEqual(
            rules, _comparison.collect_bindings([("base", blocks)], watched)
        )

    def test_unrelated_insertions_change_locations_not_rule_identity(self) -> None:
        blocks: _comparison.Keymap = [{"context": "Editor", "bindings": {"n": "next"}}]
        before = _comparison.collect_bindings([("base", blocks)], (("n",),))
        shifted: _comparison.Keymap = [
            {"context": "Other", "bindings": {"x": "unrelated"}},
            *blocks,
        ]
        after = _comparison.collect_bindings([("base", shifted)], (("n",),))
        self.assertEqual(before, after)
        self.assertNotEqual(before[0].block, after[0].block)

        reordered: _comparison.Keymap = [
            {"context": "Editor", "bindings": {"x": "unrelated", "n": "next"}}
        ]
        after = _comparison.collect_bindings([("base", reordered)], (("n",),))
        self.assertEqual(before, after)
        self.assertNotEqual(before[0].binding, after[0].binding)


class _CommandBaseline(TypedDict):
    upstream_ref: str
    sources: list[str]
    tracked_sequences: list[list[str]]
    native_rules: list[_RuleData]


class ZedComparisonCommandTest(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "native.json"
        self.source.write_text(
            '// JSONC input\n[{"context":"Editor","bindings":{"x":"first",}},]'
        )
        self.baseline = self.root / "baseline.json"
        self.data: _CommandBaseline = {
            "upstream_ref": "test-ref",
            "sources": ["native.json"],
            "tracked_sequences": [["x"]],
            "native_rules": [
                {
                    "source": "native.json",
                    "metadata": {"context": "Editor"},
                    "keystrokes": ["x"],
                    "action": "first",
                    "block": 0,
                    "binding": 0,
                }
            ],
        }
        self.baseline.write_text(json.dumps(self.data))
        self.command = [
            sys.executable,
            str(Path(__file__).resolve().with_name("compare_zed.py")),
            str(self.root),
            "--baseline",
            str(self.baseline),
        ]

    def test_unchanged_snapshot_and_read_only_inputs(self) -> None:
        before = self.source.read_text(), self.baseline.read_text()
        result = subprocess.run(
            self.command, capture_output=True, text=True, check=False
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        snapshot = subprocess.run(
            [*self.command, "--snapshot"], capture_output=True, text=True, check=False
        )
        self.assertEqual(snapshot.returncode, 0, snapshot.stderr)
        self.assertEqual(json.loads(snapshot.stdout), self.data["native_rules"])
        self.assertEqual((self.source.read_text(), self.baseline.read_text()), before)

        self.source.write_text(
            '[{"bindings":{"untracked":"ignored"}},{"context":"Editor","bindings":{"untracked":"ignored","x":"first"}}]'
        )
        shifted = subprocess.run(
            self.command, capture_output=True, text=True, check=False
        )
        self.assertEqual(shifted.returncode, 0, shifted.stderr)

    def test_semantic_changes_and_prefix_competitors_are_reported(self) -> None:
        cases = [
            [
                {
                    "context": "Editor",
                    "bindings": {"x": ["first", {"display_lines": True}]},
                }
            ],
            [
                {
                    "context": "Editor",
                    "use_key_equivalents": True,
                    "bindings": {"x": "first"},
                }
            ],
            [{"context": "Editor", "bindings": {"x": "first", "x n": "descendant"}}],
        ]
        for data in cases:
            with self.subTest(data=data):
                self.source.write_text(json.dumps(data))
                result = subprocess.run(
                    self.command, capture_output=True, text=True, check=False
                )
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertTrue(result.stdout)
                self.assertFalse(result.stderr)

    def test_missing_malformed_or_empty_selection_cannot_report_unchanged(self) -> None:
        self.data["sources"].append("missing.json")
        self.baseline.write_text(json.dumps(self.data))
        partial = subprocess.run(
            [*self.command, "--snapshot"], capture_output=True, text=True, check=False
        )
        self.assertEqual(partial.returncode, 2)
        self.assertFalse(partial.stdout)
        self.data["sources"].pop()
        self.baseline.write_text(json.dumps(self.data))

        self.source.unlink()
        missing = subprocess.run(
            self.command, capture_output=True, text=True, check=False
        )
        self.assertEqual(missing.returncode, 2)
        self.assertFalse(missing.stdout)
        self.assertTrue(missing.stderr)

        self.source.write_text("{bad JSONC")
        malformed = subprocess.run(
            self.command, capture_output=True, text=True, check=False
        )
        self.assertEqual(malformed.returncode, 2)
        self.assertFalse(malformed.stdout)
        self.assertTrue(malformed.stderr)

        self.source.write_text("[1]")
        wrong_shape = subprocess.run(
            self.command, capture_output=True, text=True, check=False
        )
        self.assertEqual(wrong_shape.returncode, 2)
        self.assertFalse(wrong_shape.stdout)

        self.source.write_text("[]")
        self.data["tracked_sequences"] = []
        self.baseline.write_text(json.dumps(self.data))
        empty = subprocess.run(
            self.command, capture_output=True, text=True, check=False
        )
        self.assertEqual(empty.returncode, 2)
        self.assertFalse(empty.stdout)


if __name__ == "__main__":
    unittest.main()
