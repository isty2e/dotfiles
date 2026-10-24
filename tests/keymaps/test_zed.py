"""Check Zed panel cycles and collect candidate rules without resolving contexts.

Requires Python 3.11 and tests/keymaps/requirements.txt, not a Zed executable.
"""

import json
import unittest
from collections.abc import Sequence
from copy import deepcopy
from dataclasses import dataclass, field
from pathlib import Path
from typing import TypeAlias, TypedDict, cast

import json5

_JsonValue: TypeAlias = (
    str | bool | int | float | None | list["_JsonValue"] | dict[str, "_JsonValue"]
)
_KeySequence: TypeAlias = tuple[str, ...]
_Keymap: TypeAlias = list[dict[str, _JsonValue]]


@dataclass(frozen=True)
class _Binding:
    source: str
    metadata: dict[str, _JsonValue]
    keystrokes: _KeySequence
    action: _JsonValue
    block: int = field(compare=False)
    binding: int = field(compare=False)

    def __post_init__(self) -> None:
        if not self.keystrokes:
            raise ValueError("A key sequence must not be empty")

    def relates_to(self, watched: Sequence[_KeySequence]) -> bool:
        return not watched or any(
            self.keystrokes[: len(key)] == key
            or key[: len(self.keystrokes)] == self.keystrokes
            for key in watched
        )


class _RuleData(TypedDict):
    source: str
    metadata: dict[str, _JsonValue]
    keystrokes: list[str]
    action: _JsonValue
    block: int
    binding: int


class _PanelData(TypedDict):
    metadata: dict[str, _JsonValue]
    cycles: list[list[str]]
    vacancies: list[str]


class _SlotData(TypedDict):
    metadata: dict[str, _JsonValue]
    keystrokes: list[str]


class _Fixture(TypedDict):
    upstream_ref: str
    native_rules: list[_RuleData]
    panels: list[_PanelData]
    outside_panel_slots: list[_SlotData]


def _collect_bindings(
    sources: Sequence[tuple[str, _Keymap]],
    watched: Sequence[_KeySequence] = (),
) -> list[_Binding]:
    collected = []
    for source, blocks in sources:
        for block_index, block in enumerate(blocks):
            bindings = block.get("bindings", {})
            if not isinstance(bindings, dict):
                raise TypeError("A bindings object must be a map")
            metadata = {
                name: value for name, value in block.items() if name != "bindings"
            }

            for binding_index, (key, action) in enumerate(bindings.items()):
                occurrence = _Binding(
                    source,
                    deepcopy(metadata),
                    tuple(key.split()),
                    deepcopy(action),
                    block_index,
                    binding_index,
                )
                if occurrence.relates_to(watched):
                    collected.append(occurrence)

    return collected


class ZedPanelTest(unittest.TestCase):
    def setUp(self) -> None:
        test_dir = Path(__file__).resolve().parent
        fixture_path = test_dir / "fixtures" / "zed-1.25.3-panels.json"
        self.fixture = cast(_Fixture, json.loads(fixture_path.read_text()))
        self.native = [
            _Binding(
                rule["source"],
                rule["metadata"],
                tuple(rule["keystrokes"]),
                rule["action"],
                rule["block"],
                rule["binding"],
            )
            for rule in self.fixture["native_rules"]
        ]
        keymap_path = test_dir.parents[1] / "zed" / "keymap.json"
        keymap = cast(_Keymap, json5.loads(keymap_path.read_text()))
        self.user = _collect_bindings([("user", keymap)])

    def test_panel_cycles_preserve_native_rules_and_vacancies(self) -> None:
        for panel in self.fixture["panels"]:
            metadata = panel["metadata"]
            before = {
                rule.keystrokes[0]: rule.action
                for rule in self.native
                if rule.metadata == metadata and len(rule.keystrokes) == 1
            }
            for vacancy in panel["vacancies"]:
                self.assertNotIn(vacancy, before)
                before[vacancy] = None
            after = before | {
                rule.keystrokes[0]: rule.action
                for rule in self.user
                if rule.metadata == metadata and len(rule.keystrokes) == 1
            }

            for cycle in panel["cycles"]:
                for source, destination in zip(
                    cycle, cycle[1:] + cycle[:1], strict=True
                ):
                    with self.subTest(
                        context=metadata, source=source, destination=destination
                    ):
                        self.assertEqual(after[destination], before[source])

    def test_panel_footprint_and_other_competing_key_slots(self) -> None:
        watched = tuple(
            (key,) for key in ("h", "j", "n", "k", "e", "i", "u", "l", "alt-l")
        )
        outside_slots = [
            (slot["metadata"], tuple(slot["keystrokes"]))
            for slot in self.fixture["outside_panel_slots"]
        ]
        for rule in self.user:
            context = rule.metadata.get("context", "")
            is_panel = isinstance(context, str) and any(
                name in context for name in ("ProjectPanel", "OutlinePanel", "GitPanel")
            )
            with self.subTest(context=context, key=rule.keystrokes):
                if is_panel:
                    matches = [
                        p
                        for p in self.fixture["panels"]
                        if p["metadata"] == rule.metadata
                    ]
                    self.assertEqual(len(matches), 1)
                    allowed = {
                        (key,) for cycle in matches[0]["cycles"] for key in cycle
                    }
                    self.assertIn(rule.keystrokes, allowed)
                elif rule.relates_to(watched):
                    self.assertIn((rule.metadata, rule.keystrokes), outside_slots)

    def test_prediction_candidate_rules_remain_inherited(self) -> None:
        watched = (("alt-l",),)
        native = [rule for rule in self.native if rule.relates_to(watched)]
        combined = native + [rule for rule in self.user if rule.relates_to(watched)]
        self.assertEqual(combined, native)


class ZedCandidateTest(unittest.TestCase):
    def test_prefix_family_order_metadata_and_arguments_are_preserved(self) -> None:
        blocks: _Keymap = [
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
        rules = _collect_bindings([("base", blocks)], watched)
        self.assertEqual(
            [rule.keystrokes for rule in rules],
            [("g",), ("g", "n"), ("g", "n", "x"), ("g", "n")],
        )
        self.assertEqual(rules[-1].metadata["use_key_equivalents"], True)
        self.assertIsNone(rules[-1].action)
        self.assertNotEqual(rules, list(reversed(rules)))

        later: _Keymap = [{"context": "Editor", "bindings": {"g n": "later"}}]
        combined = _collect_bindings([("z-base", blocks), ("a-user", later)], watched)
        self.assertEqual(
            [rule.source for rule in combined], ["z-base"] * 4 + ["a-user"]
        )

        bindings = cast(dict[str, _JsonValue], blocks[0]["bindings"])
        bindings["g n x"] = ["motion", {"display_lines": False}]
        self.assertNotEqual(rules, _collect_bindings([("base", blocks)], watched))

    def test_unrelated_insertions_change_locations_not_rule_identity(self) -> None:
        blocks: _Keymap = [{"context": "Editor", "bindings": {"n": "next"}}]
        before = _collect_bindings([("base", blocks)], (("n",),))
        shifted: _Keymap = [
            {"context": "Other", "bindings": {"x": "unrelated"}},
            *blocks,
        ]
        after = _collect_bindings([("base", shifted)], (("n",),))
        self.assertEqual(before, after)
        self.assertNotEqual(before[0].block, after[0].block)

        reordered: _Keymap = [
            {"context": "Editor", "bindings": {"x": "unrelated", "n": "next"}}
        ]
        after = _collect_bindings([("base", reordered)], (("n",),))
        self.assertEqual(before, after)
        self.assertNotEqual(before[0].binding, after[0].binding)


if __name__ == "__main__":
    unittest.main()
