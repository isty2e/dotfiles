"""Compare tracked Zed rules without evaluating contexts or changing keymaps.

Requires Python 3.11+ and tests/keymaps/requirements.txt, not a Zed executable.
"""

import argparse
import json
import sys
from collections.abc import Sequence
from copy import deepcopy
from dataclasses import asdict, dataclass, field, fields
from difflib import unified_diff
from pathlib import Path
from typing import TypeAlias, TypedDict, cast

import json5

JsonValue: TypeAlias = (
    str | bool | int | float | None | list["JsonValue"] | dict[str, "JsonValue"]
)
KeySequence: TypeAlias = tuple[str, ...]
Keymap: TypeAlias = list[dict[str, JsonValue]]


@dataclass(frozen=True, eq=False)
class Binding:
    """A native rule with semantic data and diagnostic source locators.

    Parameters
    ----------
    source : str
        Source name within the configured catalogue.
    metadata : dict[str, JsonValue]
        Complete block metadata except its bindings map.
    keystrokes : KeySequence
        Nonempty sequence of native keystroke tokens.
    action : JsonValue
        Native action and arguments, including null unbindings.
    block, binding : int
        Zero-based locators, excluded from equality. List order retains definition order.

    Raises
    ------
    ValueError
        If the key sequence is empty.
    """

    source: str
    metadata: dict[str, JsonValue]
    keystrokes: KeySequence
    action: JsonValue
    block: int = field(compare=False)
    binding: int = field(compare=False)

    def __post_init__(self) -> None:
        if not self.keystrokes:
            raise ValueError("A key sequence must not be empty")

    def _identity(self) -> str:
        data = asdict(self)
        for item in fields(self):
            if not item.compare:
                del data[item.name]
        return json.dumps(data, sort_keys=True)

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Binding):
            return NotImplemented
        return self._identity() == other._identity()

    def relates_to(self, watched: Sequence[KeySequence]) -> bool:
        """Select exact keys and prefix-comparable ancestors or descendants.

        Parameters
        ----------
        watched : Sequence[KeySequence]
            Tracked sequences; an empty collection selects every rule.

        Returns
        -------
        bool
            Whether the rule belongs to a tracked prefix family.
        """
        return not watched or any(
            self.keystrokes[: len(key)] == key
            or key[: len(self.keystrokes)] == self.keystrokes
            for key in watched
        )


def collect_bindings(
    sources: Sequence[tuple[str, Keymap]],
    watched: Sequence[KeySequence] = (),
) -> list[Binding]:
    """Collect independent rule values in the caller's source/definition order.

    Parameters
    ----------
    sources : Sequence[tuple[str, Keymap]]
        Source names paired with loaded native JSONC objects.
    watched : Sequence[KeySequence]
        Tracked prefix families; an empty collection selects every rule.

    Returns
    -------
    list[Binding]
        Matching rules with complete metadata, arguments and source locators.

    Raises
    ------
    TypeError
        If a bindings value is not a map.
    ValueError
        If a rule has an empty key sequence.
    """
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
                occurrence = Binding(
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


class _RuleData(TypedDict):
    source: str
    metadata: dict[str, JsonValue]
    keystrokes: list[str]
    action: JsonValue
    block: int
    binding: int


class _BaselineData(TypedDict):
    upstream_ref: str
    sources: list[str]
    tracked_sequences: list[list[str]]
    native_rules: list[_RuleData]


def _render_rules(rules: Sequence[Binding]) -> list[str]:
    return json.dumps(
        [json.loads(rule._identity()) for rule in rules],
        indent=2,
        sort_keys=True,
    ).splitlines(keepends=True)


def _main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare the fixture's tracked rules; no context evaluation or writes.",
        epilog="Exit codes: 0 unchanged/snapshot, 1 changed, 2 input error.",
    )
    parser.add_argument(
        "source_dir", type=Path, help="Directory containing assets/keymaps inputs"
    )
    parser.add_argument(
        "--baseline",
        type=Path,
        required=True,
        help="Fixture defining sources, tracked sequences and reviewed native rules",
    )
    parser.add_argument(
        "--snapshot",
        action="store_true",
        help="Emit native_rules JSON to stdout instead of comparing",
    )
    args = parser.parse_args()

    try:
        baseline = cast(_BaselineData, json.loads(args.baseline.read_text()))
        watched = tuple(tuple(key) for key in baseline["tracked_sequences"])
        if not baseline["sources"] or not watched or any(not key for key in watched):
            raise ValueError(
                "The source catalogue and tracked sequences must not be empty"
            )
        sources = [
            (name, cast(Keymap, json5.loads((args.source_dir / name).read_text())))
            for name in baseline["sources"]
        ]
        actual = collect_bindings(sources, watched)
        if args.snapshot:
            print(json.dumps([asdict(rule) for rule in actual], indent=2))
            return 0
        expected = [
            Binding(
                row["source"],
                row["metadata"],
                tuple(row["keystrokes"]),
                row["action"],
                row["block"],
                row["binding"],
            )
            for row in baseline["native_rules"]
        ]
    except (AttributeError, OSError, ValueError, KeyError, TypeError) as error:
        print(f"Cannot compare keymaps: {error}", file=sys.stderr)
        return 2

    if expected == actual:
        print(f"No tracked rule changes relative to {baseline['upstream_ref']}.")
        return 0
    sys.stdout.writelines(
        unified_diff(
            _render_rules(expected),
            _render_rules(actual),
            fromfile=baseline["upstream_ref"],
            tofile="candidate",
        )
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(_main())
