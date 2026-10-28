#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tarfile
from collections.abc import Sequence
from dataclasses import dataclass
from enum import Enum
from pathlib import Path, PurePosixPath
from typing import Union, cast

_Json = Union[None, bool, int, float, str, list["_Json"], dict[str, "_Json"]]
_SUPPORTED = frozenset({"2.73.3"})
_EXCLUDED_TYPES = "externals,encrypted,templates"


class _Arguments(argparse.Namespace):
    check: bool
    targets: list[str]


class _Failure(RuntimeError):
    def __init__(self, message: str, code: int = 2) -> None:
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class _FileState:
    mode: int
    digest: bytes


class _Decision(Enum):
    UNCHANGED = "unchanged"
    CAPTURE = "ready"
    NEEDS_APPLY = "needs reviewed apply"
    SOURCE_CHANGED = (
        "desired output differs from recorded state; "
        "review source and effective settings (including umask)"
    )


def _decide(
    recorded: _FileState | None, desired: _FileState, live: _FileState
) -> _Decision:
    if recorded is None or desired == live != recorded:
        return _Decision.NEEDS_APPLY
    if desired != recorded:
        return _Decision.SOURCE_CHANGED
    return _Decision.UNCHANGED if desired == live else _Decision.CAPTURE


@dataclass(frozen=True)
class _Observation:
    state: _FileState
    stamp: tuple[int, int, int, int, int, int]
    links: int


@dataclass(frozen=True)
class _Binding:
    relative: str
    absolute: str
    source: Path
    source_relative: str


@dataclass(frozen=True)
class _Context:
    source: Path
    destination: Path
    configuration: bytes


@dataclass(frozen=True)
class _Candidate:
    binding: _Binding
    recorded: _FileState | None
    desired: _FileState
    live: _Observation
    source: _Observation

    @property
    def decision(self) -> _Decision:
        return _decide(self.recorded, self.desired, self.live.state)


@dataclass(frozen=True)
class _Snapshot:
    context: _Context
    policy: tuple[str, ...]
    candidates: tuple[_Candidate, ...]
    excluded: tuple[str, ...]


class _Chezmoi:
    def __init__(self, executable: Path) -> None:
        self.executable = executable

    @classmethod
    def discover(cls) -> _Chezmoi:
        selected = shutil.which(os.environ.get("CHEZMOI", "chezmoi"))
        if selected is None:
            raise _Failure("chezmoi is unavailable; select an installed executable")
        executable = Path(selected).resolve()
        if executable.name == "mise":
            raise _Failure("select a real chezmoi executable, not a mise shim")
        native = cls(executable)
        version = native.run("--version").decode("utf-8", errors="replace")
        match = re.match(r"chezmoi version v(\d+\.\d+\.\d+)(?:[,\s]|$)", version)
        if match is None or match[1] not in _SUPPORTED:
            raise _Failure("unsupported chezmoi version; tested version: 2.73.3")
        return native

    def run(self, *arguments: str) -> bytes:
        try:
            result = subprocess.run(
                [str(self.executable), "--no-tty", "--no-pager", *arguments],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                check=False,
            )
        except OSError as error:
            raise _Failure("could not execute chezmoi") from error
        if result.returncode:
            raise _Failure(f"native {arguments[0]} failed (exit {result.returncode})")
        return result.stdout


def _json(raw: bytes) -> _Json:
    try:
        return cast(_Json, json.loads(raw))
    except (ValueError, UnicodeError) as error:
        raise _Failure("invalid native JSON") from error


def _object(value: _Json) -> dict[str, _Json]:
    if not isinstance(value, dict):
        raise _Failure("unexpected native object shape")
    return value


def _text(value: _Json) -> str:
    if not isinstance(value, str) or not value or "\0" in value:
        raise _Failure("expected a nonempty native string")
    return value


def _quoted(value: str) -> str:
    """Escape target paths so each diagnostic stays on one terminal line."""
    return json.dumps(value)


def _context(native: _Chezmoi) -> _Context:
    raw = native.run("dump-config", "--format=json")
    config = _object(_json(raw))
    if config.get("mode") != "file":
        raise _Failure("only chezmoi copy mode is supported")
    git = _object(config.get("git"))
    for key in ("autoadd", "autocommit", "autopush"):
        if git.get(key) is not False:
            raise _Failure("native automatic Git actions must be disabled")
    hooks = config.get("hooks")
    if hooks is not None and _object(hooks).get("re-add"):
        raise _Failure("native re-add mutation hooks are not supported")
    source = Path(_text(config.get("sourceDir")))
    destination = Path(_text(config.get("destDir")))
    if not source.is_absolute() or not destination.is_absolute():
        raise _Failure("native source and destination must be absolute")
    return _Context(source, destination, raw)


def _selector(value: str, destination: Path) -> str:
    if not value or "\0" in value:
        raise _Failure("empty or invalid target selector")
    relative = (
        os.path.relpath(value, destination)
        if Path(value).is_absolute()
        else os.path.normpath(value)
    )
    if relative == ".." or relative.startswith("../"):
        raise _Failure("target selector is outside the native destination")
    return PurePosixPath(relative).as_posix()


def _matches(target: str, selector: str) -> bool:
    return selector == "." or target == selector or target.startswith(selector + "/")


def _managed(native: _Chezmoi, include: str, exclude: str) -> dict[str, _Json]:
    return _object(
        _json(
            native.run(
                "managed",
                f"--include={include}",
                f"--exclude={exclude}",
                "--path-style=all",
                "--format=json",
            )
        )
    )


def _binding(relative: str, value: _Json, context: _Context) -> _Binding:
    record = _object(value)
    absolute = _text(record.get("absolute"))
    source = Path(_text(record.get("sourceAbsolute")))
    source_relative = _text(record.get("sourceRelative"))
    if (
        relative == "."
        or _selector(relative, context.destination) != relative
        or absolute != str(context.destination / relative)
        or not source.is_absolute()
        or os.path.normpath(str(source)) != str(source)
        or not source.is_relative_to(context.source)
        or PurePosixPath(source_relative).is_absolute()
        or ".." in PurePosixPath(source_relative).parts
        or str(PurePosixPath(source_relative)) != source_relative
        or PurePosixPath(source_relative).name != source.name
    ):
        raise _Failure("inconsistent native target/source binding")
    return _Binding(relative, absolute, source, source_relative)


def _policy(native: _Chezmoi, destination: Path) -> tuple[str, ...]:
    policy = _object(_json(native.run("execute-template", "{{ .capture | toJson }}")))
    if set(policy) != {"paths"}:
        raise _Failure("capture policy must contain only paths")
    paths = policy.get("paths")
    if not isinstance(paths, list) or not paths:
        raise _Failure("capture.paths must be a nonempty list")
    return tuple(sorted({_selector(_text(path), destination) for path in paths}))


def _select(
    bindings: dict[str, _Binding], policy: tuple[str, ...], selectors: Sequence[str]
) -> tuple[_Binding, ...]:
    allowed: set[str] = set()
    for root in policy:
        matches = {name for name in bindings if _matches(name, root)}
        if not matches:
            raise _Failure(f"policy selects no eligible target: {_quoted(root)}")
        allowed.update(matches)
    if selectors:
        selected: set[str] = set()
        for selector in selectors:
            matches = {name for name in allowed if _matches(name, selector)}
            if not matches:
                raise _Failure(f"not an eligible policy target: {_quoted(selector)}")
            selected.update(matches)
    else:
        selected = allowed
    return tuple(bindings[name] for name in sorted(selected))


def _stamp(info: os.stat_result) -> tuple[int, int, int, int, int, int]:
    return (
        info.st_dev,
        info.st_ino,
        info.st_mode,
        info.st_size,
        info.st_mtime_ns,
        info.st_ctime_ns,
    )


def _observe(path: Path) -> _Observation:
    try:
        if not stat.S_ISREG(path.lstat().st_mode):
            raise _Failure("source/live path is not a regular file")
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        try:
            before = os.fstat(descriptor)
            if not stat.S_ISREG(before.st_mode):
                raise _Failure("source/live path is not a regular file")
            digest = hashlib.sha256()
            while True:
                block = os.read(descriptor, 131072)
                if not block:
                    break
                digest.update(block)
            after = os.fstat(descriptor)
            if _stamp(before) != _stamp(after) or _stamp(after) != _stamp(path.lstat()):
                raise _Failure("source/live file changed while reading")
        finally:
            os.close(descriptor)
    except OSError as error:
        raise _Failure("source/live file is missing or unreadable") from error
    return _Observation(
        _FileState(stat.S_IMODE(after.st_mode) & 0o777, digest.digest()),
        _stamp(after),
        after.st_nlink,
    )


def _baseline(value: _Json) -> _FileState | None:
    record = _object(value)
    kind = _text(record.get("type"))
    if kind != "file":
        return None
    mode = record.get("mode", 0)
    if type(mode) is not int or not 0 <= mode <= 0xFFFFFFFF:
        raise _Failure("invalid native file mode")
    digest = _text(record.get("contentsSHA256"))
    if re.fullmatch(r"[0-9a-fA-F]{64}", digest) is None:
        raise _Failure("invalid native file digest")
    return _FileState(mode & 0o777, bytes.fromhex(digest))


def _desired(native: _Chezmoi, bindings: tuple[_Binding, ...]) -> dict[str, _FileState]:
    if not bindings:
        return {}
    archive = native.run(
        "archive",
        "--format=tar",
        "--gzip=false",
        "--parent-dirs=false",
        "--recursive=false",
        f"--exclude={_EXCLUDED_TYPES}",
        "--",
        *(binding.absolute for binding in bindings),
    )
    expected = {binding.relative for binding in bindings}
    desired: dict[str, _FileState] = {}
    try:
        with tarfile.open(fileobj=io.BytesIO(archive), mode="r:") as stream:
            for member in stream:
                if (
                    not member.isfile()
                    or member.name not in expected
                    or member.name in desired
                ):
                    raise _Failure("unexpected or duplicate desired archive member")
                body = stream.extractfile(member)
                if body is None:
                    raise _Failure("missing desired archive member contents")
                with body:
                    digest = hashlib.sha256(body.read()).digest()
                desired[member.name] = _FileState(member.mode & 0o777, digest)
    except (tarfile.TarError, OSError, ValueError) as error:
        raise _Failure("invalid desired archive") from error
    if set(desired) != expected:
        raise _Failure("desired archive does not match the selected targets")
    return desired


def _snapshot(native: _Chezmoi, selectors: Sequence[str]) -> _Snapshot:
    context = _context(native)
    policy = _policy(native, context.destination)
    inventory = _managed(native, "files,symlinks,externals", "none")
    raw = _managed(native, "files", _EXCLUDED_TYPES)
    bindings = {}
    for relative, entry in raw.items():
        binding = _binding(relative, entry, context)
        if not binding.source.name.startswith(("create_", "modify_")):
            bindings[relative] = binding
    normalized = tuple(_selector(value, context.destination) for value in selectors)
    selected = _select(bindings, policy, normalized)
    excluded = tuple(
        sorted(
            name
            for name in set(inventory) - set(bindings)
            if any(_matches(name, root) for root in policy)
            and (not normalized or any(_matches(name, root) for root in normalized))
        )
    )
    sources = {}
    identities: set[tuple[int, int]] = set()
    for binding in selected:
        try:
            observation = _observe(binding.source)
        except _Failure as error:
            raise _Failure(f"{_quoted(binding.relative)}: {error}") from error
        identity = (observation.stamp[0], observation.stamp[1])
        if observation.links != 1 or identity in identities:
            raise _Failure("hardlinked or aliased source files are not supported")
        identities.add(identity)
        sources[binding.relative] = observation
    recorded = _object(
        _json(native.run("state", "get-bucket", "--bucket=entryState", "--format=json"))
    )
    desired = _desired(native, selected)
    candidates = []
    for binding in selected:
        try:
            previous = (
                _baseline(recorded[binding.absolute])
                if binding.absolute in recorded
                else None
            )
            live = _observe(Path(binding.absolute))
        except _Failure as error:
            raise _Failure(f"{_quoted(binding.relative)}: {error}") from error
        candidates.append(
            _Candidate(
                binding,
                previous,
                desired[binding.relative],
                live,
                sources[binding.relative],
            )
        )
    return _Snapshot(context, policy, tuple(candidates), excluded)


def _capture(
    native: _Chezmoi, before: _Snapshot, targets: tuple[_Candidate, ...]
) -> None:
    try:
        # Retain native cleanup actions for permission-driven source renames.
        native.run(
            "re-add",
            f"--exclude={_EXCLUDED_TYPES}",
            "--recursive=false",
            "--interactive=false",
            "--keep-going=false",
            "--",
            *(candidate.binding.absolute for candidate in targets),
        )
        after = _snapshot(native, [candidate.binding.relative for candidate in targets])
        if after.context != before.context or after.policy != before.policy:
            raise _Failure("native context or policy changed during capture")
        if tuple(candidate.binding.relative for candidate in after.candidates) != tuple(
            candidate.binding.relative for candidate in targets
        ):
            raise _Failure("captured target identities changed")
        if any(
            candidate.decision != _Decision.UNCHANGED for candidate in after.candidates
        ):
            raise _Failure("capture post-check did not confirm equal file states")
    except (_Failure, KeyboardInterrupt) as error:
        message = str(error) if isinstance(error, _Failure) else "interrupted"
        raise _Failure(
            f"{message}; source/state may be partially changed; inspect before retrying",
            1,
        ) from error


def _main(arguments: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Collect live-only edits to managed copied files."
    )
    parser.add_argument(
        "--check", action="store_true", help="preflight without capture"
    )
    parser.add_argument(
        "targets", nargs="*", help="destination-relative or absolute target prefixes"
    )
    args = parser.parse_args(arguments, namespace=_Arguments())
    try:
        native = _Chezmoi.discover()
        before = _snapshot(native, args.targets)
        for name in before.excluded:
            print(f"EXCLUDED {_quoted(name)}: not an ordinary copied file")
        blocked = False
        targets = []
        for candidate in before.candidates:
            decision = candidate.decision
            print(
                f"{decision.name} {_quoted(candidate.binding.relative)}: {decision.value}"
            )
            if decision == _Decision.CAPTURE:
                targets.append(candidate)
            elif decision != _Decision.UNCHANGED:
                blocked = True
        if blocked:
            raise _Failure("preflight blocked; no capture attempted")
        if args.check or not targets:
            return 0
        if _snapshot(native, args.targets) != before:
            raise _Failure("preflight inputs changed; no capture attempted")
        _capture(native, before, tuple(targets))
        for candidate in targets:
            print(f"CAPTURED {_quoted(candidate.binding.relative)}")
        return 0
    except _Failure as error:
        print(f"{'FAILED' if error.code == 1 else 'BLOCKED'}: {error}", file=sys.stderr)
        return error.code
    except KeyboardInterrupt:
        print("BLOCKED: interrupted before capture", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(_main())
