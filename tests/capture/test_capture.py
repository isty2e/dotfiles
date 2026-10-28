import contextlib
import hashlib
import io
import json
import os
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch

from home.dot_local.bin import executable_dotfiles_capture as capture

REPO = Path(__file__).resolve().parents[2]
PROGRAM = REPO / "home/dot_local/bin/executable_dotfiles_capture.py"
CHEZMOI = shutil.which(os.environ.get("CHEZMOI", "chezmoi"))
GIT = shutil.which("git")


def _state(body: bytes = b"original", mode: int = 0o644) -> capture._FileState:
    return capture._FileState(mode, hashlib.sha256(body).digest())


class ComparisonTests(unittest.TestCase):
    def test_diagnostic_paths_cannot_inject_terminal_lines(self) -> None:
        path = ".config/space and\ncontrol\x1bfile"
        rendered = capture._quoted(path)
        self.assertEqual(json.loads(rendered), path)
        self.assertNotIn("\n", rendered)
        self.assertNotIn("\x1b", rendered)

    def test_comparison_partitions(self) -> None:
        original, source, live = _state(), _state(b"source"), _state(b"live")
        cases = (
            (None, original, original, capture._Decision.NEEDS_APPLY),
            (original, original, original, capture._Decision.UNCHANGED),
            (original, original, live, capture._Decision.CAPTURE),
            (original, source, original, capture._Decision.SOURCE_CHANGED),
            (original, source, live, capture._Decision.SOURCE_CHANGED),
            (original, source, source, capture._Decision.NEEDS_APPLY),
            (original, original, _state(mode=0o600), capture._Decision.CAPTURE),
        )
        for recorded, desired, actual, expected in cases:
            with self.subTest(recorded=recorded, desired=desired, actual=actual):
                self.assertEqual(capture._decide(recorded, desired, actual), expected)

    def test_native_baseline_decoding(self) -> None:
        expected = _state(b"", 0)
        self.assertEqual(
            capture._baseline(
                {
                    "type": "file",
                    "contentsSHA256": expected.digest.hex(),
                }
            ),
            expected,
        )
        self.assertIsNone(capture._baseline({"type": "symlink"}))
        invalid: tuple[capture._Json, ...] = (
            None,
            [],
            {"type": "file"},
            {"type": "file", "mode": True, "contentsSHA256": expected.digest.hex()},
            {"type": "file", "mode": -1, "contentsSHA256": expected.digest.hex()},
            {"type": "file", "mode": 0, "contentsSHA256": "bad digest"},
        )
        for value in invalid:
            with self.subTest(value=value), self.assertRaises(capture._Failure):
                capture._baseline(value)

    def test_selection_cannot_expand_policy(self) -> None:
        root = Path("/destination")
        bindings = {
            name: capture._Binding(name, str(root / name), Path("/source") / name, name)
            for name in (".first", ".second", ".config/editor/settings")
        }
        selected = capture._select(bindings, (".config",), (".",))
        self.assertEqual(
            [item.relative for item in selected], [".config/editor/settings"]
        )
        for policy, selectors in (((".first",), (".second",)), ((".missing",), ())):
            with self.subTest(policy=policy), self.assertRaises(capture._Failure):
                capture._select(bindings, policy, selectors)
        self.assertEqual(capture._selector("/destination/.first", root), ".first")
        with self.assertRaises(capture._Failure):
            capture._selector("/elsewhere/.first", root)

    def test_empty_plan_never_calls_native_capture(self) -> None:
        native = capture._Chezmoi(Path("/unused"))
        binding = capture._Binding(
            ".first", "/destination/.first", Path("/source/first"), "first"
        )
        observation = capture._Observation(_state(), (1, 2, 3, 4, 5, 6), 1)
        candidate = capture._Candidate(
            binding, _state(), _state(), observation, observation
        )
        snapshot = capture._Snapshot(
            capture._Context(Path("/source"), Path("/destination"), b""),
            (".",),
            (candidate,),
            (),
        )
        with (
            patch.object(capture._Chezmoi, "discover", return_value=native),
            patch.object(capture, "_snapshot", return_value=snapshot),
            patch.object(native, "run") as run,
            contextlib.redirect_stdout(io.StringIO()),
        ):
            self.assertEqual(capture._main([]), 0)
        run.assert_not_called()

        ready = replace(candidate, live=replace(observation, state=_state(b"local")))
        blocked = replace(
            candidate,
            binding=replace(binding, relative=".second"),
            desired=_state(b"changed source"),
        )
        mixed = replace(snapshot, candidates=(ready, blocked))
        with (
            patch.object(capture._Chezmoi, "discover", return_value=native),
            patch.object(capture, "_snapshot", return_value=mixed),
            patch.object(native, "run") as run,
            contextlib.redirect_stdout(io.StringIO()),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            self.assertEqual(capture._main([]), 2)
        run.assert_not_called()

    def test_unavailable_and_unsupported_native_tools_block(self) -> None:
        with (
            patch.dict(os.environ, {"CHEZMOI": "/missing/capture-fixture-chezmoi"}),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            self.assertEqual(capture._main([]), 2)
        with (
            patch("shutil.which", return_value="/not-mise/chezmoi"),
            patch.object(
                capture._Chezmoi, "run", return_value=b"chezmoi version v9.0.0"
            ),
            self.assertRaises(capture._Failure),
        ):
            capture._Chezmoi.discover()

    def test_archive_rejects_unexpected_members_without_extraction(self) -> None:
        binding = capture._Binding(
            ".first", "/destination/.first", Path("/source/first"), "first"
        )
        for name, kind in (("../escape", tarfile.REGTYPE), (".first", tarfile.SYMTYPE)):
            archive = io.BytesIO()
            with tarfile.open(fileobj=archive, mode="w") as stream:
                member = tarfile.TarInfo(name)
                member.type = kind
                stream.addfile(member)
            native = capture._Chezmoi(Path("/unused"))
            with (
                patch.object(native, "run", return_value=archive.getvalue()),
                self.assertRaises(capture._Failure),
            ):
                capture._desired(native, (binding,))

    def test_native_failures_do_not_echo_output(self) -> None:
        failure = subprocess.CompletedProcess(
            [], 7, b"private output", b"private error"
        )
        native = capture._Chezmoi(Path("/unused"))
        with (
            patch("subprocess.run", return_value=failure),
            self.assertRaises(capture._Failure) as raised,
        ):
            native.run("managed")
        self.assertNotIn("private", str(raised.exception))


@unittest.skipUnless(CHEZMOI, "chezmoi is required for native capture integration")
class NativeCaptureTests(unittest.TestCase):
    def setUp(self) -> None:
        assert CHEZMOI is not None
        version = subprocess.check_output([CHEZMOI, "--version"], text=True)
        if not version.startswith("chezmoi version v2.73.3,"):
            self.skipTest("native capture tests require the supported chezmoi 2.73.3")
        temporary = tempfile.TemporaryDirectory(prefix="capture native ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.source = self.root / "source"
        self.destination = self.root / "destination"
        self.home = self.root / "process-home"
        (self.source / "home/dot_local/bin").mkdir(parents=True)
        self.destination.mkdir()
        (self.home / ".config/chezmoi").mkdir(parents=True)
        (self.source / ".chezmoiroot").write_text("home\n")
        shutil.copyfile(
            PROGRAM, self.source / "home/dot_local/bin/executable_dotfiles_capture.py"
        )
        shutil.copyfile(
            REPO / "home/dot_local/bin/symlink_dotfiles-capture",
            self.source / "home/dot_local/bin/symlink_dotfiles-capture",
        )
        self.policy = self.source / "home/.chezmoidata.toml"
        shutil.copyfile(REPO / "home/.chezmoidata.toml", self.policy)
        self.first = self.source / "home/dot_first"
        self.second = self.source / "home/dot_second"
        self.first.write_bytes(b"first original\n")
        self.second.write_bytes(b"second original\n")
        self.configuration = self.home / ".config/chezmoi/chezmoi.toml"
        self.configuration.write_text(
            f"sourceDir={json.dumps(str(self.source))}\n"
            f"destDir={json.dumps(str(self.destination))}\n"
        )
        self.environment = {
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_CACHE_HOME": str(self.home / ".cache"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "XDG_STATE_HOME": str(self.home / ".local/state"),
            "PATH": str(Path(sys.executable).parent) + os.pathsep + os.defpath,
            "CHEZMOI": str(Path(CHEZMOI).resolve()),
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
        }
        self._native("apply")
        self.program = self.destination / ".local/bin/dotfiles-capture"

    def _native(self, *arguments: str) -> bytes:
        assert CHEZMOI is not None
        result = subprocess.run(
            [CHEZMOI, *arguments],
            env=self.environment,
            cwd=self.root,
            capture_output=True,
            timeout=30,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def _guard(self, *arguments: str) -> subprocess.CompletedProcess[bytes]:
        return subprocess.run(
            [str(self.program), *arguments],
            env=self.environment,
            cwd=self.root,
            capture_output=True,
            timeout=30,
            check=False,
        )

    def _in_process(self, *arguments: str) -> int:
        with (
            patch.dict(os.environ, self.environment, clear=True),
            contextlib.redirect_stdout(io.StringIO()),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            return capture._main(arguments)

    def test_live_only_capture_and_check_preserve_baseline(self) -> None:
        (self.destination / ".first").write_bytes(b"local edit\n")
        baseline = self._native(
            "state", "get-bucket", "--bucket=entryState", "--format=json"
        )
        checked = self._guard("--check")
        self.assertEqual(checked.returncode, 0, checked.stderr)
        self.assertEqual(self.first.read_bytes(), b"first original\n")
        self.assertEqual(
            self._native("state", "get-bucket", "--bucket=entryState", "--format=json"),
            baseline,
        )
        result = self._guard()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.first.read_bytes(), b"local edit\n")
        self.assertEqual(self._guard().returncode, 0)

    def test_mixed_batch_blocks_without_copying_any_local_edit(self) -> None:
        self.first.write_bytes(b"source edit\n")
        (self.destination / ".second").write_bytes(b"local second\n")
        result = self._guard()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.first.read_bytes(), b"source edit\n")
        self.assertEqual(self.second.read_bytes(), b"second original\n")
        self.assertEqual(self._guard(".second").returncode, 0)
        self.assertEqual(self.second.read_bytes(), b"local second\n")

    def test_both_sides_and_matching_but_stale_baseline_block(self) -> None:
        self.first.write_bytes(b"source edit\n")
        (self.destination / ".first").write_bytes(b"different local edit\n")
        self.assertEqual(self._guard(".first").returncode, 2)
        (self.destination / ".first").write_bytes(self.first.read_bytes())
        self.assertEqual(self._guard(".first").returncode, 2)
        self._native("apply", str(self.destination / ".first"))
        self.assertEqual(self._guard(".first").returncode, 0)

    def test_noop_readd_does_not_initialize_a_baseline(self) -> None:
        source = self.source / "home/dot_new"
        target = self.destination / ".new"
        source.write_bytes(b"matching\n")
        target.write_bytes(source.read_bytes())
        self._native("re-add", str(target))
        self.assertEqual(self._guard(".new").returncode, 2)
        self._native("apply", str(target))
        self.assertEqual(self._guard(".new").returncode, 0)

    def test_partial_apply_does_not_acknowledge_another_source_change(self) -> None:
        self.first.write_bytes(b"new first\n")
        self.second.write_bytes(b"new second\n")
        self._native("apply", str(self.destination / ".first"))
        self.assertEqual(self._guard(".first").returncode, 0)
        self.assertEqual(self._guard(".second").returncode, 2)

    def test_permission_capture_refreshes_source_binding(self) -> None:
        (self.destination / ".first").chmod(0o600)
        result = self._guard(".first")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            (self.source / "home/private_dot_first").read_bytes(), b"first original\n"
        )
        self.assertEqual(self._guard(".first").returncode, 0)

    def test_changed_effective_umask_blocks_without_a_source_content_edit(self) -> None:
        original = self.configuration.read_text()
        target = self.destination / ".first"
        self.configuration.write_text("umask = 0o022\n" + original)
        self._native("apply", str(target))
        baseline = self._native(
            "state", "get-bucket", "--bucket=entryState", "--format=json"
        )
        source = self.first.read_bytes()
        live = target.read_bytes()
        mode = target.stat().st_mode

        self.configuration.write_text("umask = 0o077\n" + original)
        result = self._guard(".first")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn(b"SOURCE_CHANGED", result.stdout)
        self.assertEqual(self.first.read_bytes(), source)
        self.assertEqual(target.read_bytes(), live)
        self.assertEqual(target.stat().st_mode, mode)
        self.assertEqual(
            self._native("state", "get-bucket", "--bucket=entryState", "--format=json"),
            baseline,
        )

    def test_executable_and_empty_file_source_renames(self) -> None:
        target = self.destination / ".first"
        target.chmod(0o755)
        result = self._guard(".first")
        self.assertEqual(result.returncode, 0, result.stderr)
        target.write_bytes(b"")
        result = self._guard(".first")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self._guard(".first").returncode, 0)

    def test_edit_apply_records_the_new_baseline(self) -> None:
        editor = self.root / "fixture editor"
        editor.write_text('#!/bin/sh\nprintf "edited source\\n" > "$1"\n')
        editor.chmod(0o755)
        self.environment["EDITOR"] = shlex.quote(str(editor))
        self.environment["VISUAL"] = shlex.quote(str(editor))
        self._native("edit", "--apply", str(self.destination / ".first"))
        self.assertEqual(self.first.read_bytes(), b"edited source\n")
        self.assertEqual(self._guard(".first").returncode, 0)

    def test_binary_and_unusual_names_roundtrip(self) -> None:
        for name in (".name with space", ".줄바꿈\nfile"):
            source = self.source / "home" / ("dot_" + name[1:])
            target = self.destination / name
            source.write_bytes(b"\x00\xff\x80old\n")
            self._native("apply", str(target))
            target.write_bytes(b"\x00\xff\x80new\n")
            result = self._guard(str(target))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(source.read_bytes(), target.read_bytes())
            self.assertNotIn(b"\xff", result.stdout + result.stderr)

    def test_unmanaged_and_outside_policy_targets_block(self) -> None:
        self.policy.write_text('[capture]\npaths=[".first"]\n')
        (self.destination / ".second").write_bytes(b"local second\n")
        self.assertEqual(self._guard(".second").returncode, 2)
        self.assertEqual(self._guard(".unmanaged").returncode, 2)
        self.assertEqual(self.second.read_bytes(), b"second original\n")

    def test_missing_empty_and_malformed_policies_block(self) -> None:
        for policy in (
            "",
            "[capture]\npaths=[]\n",
            '[capture]\npaths="wrong"\n',
            '[capture]\npaths=["."]\nexclude=[".first"]\n',
        ):
            self.policy.write_text(policy)
            self.assertEqual(self._guard().returncode, 2)

    def test_missing_and_symlink_live_files_block(self) -> None:
        target = self.destination / ".first"
        target.unlink()
        self.assertEqual(self._guard(".first").returncode, 2)
        target.symlink_to(self.second)
        self.assertEqual(self._guard(".first").returncode, 2)

    def test_unsupported_recipes_are_excluded_without_rendering(self) -> None:
        directory = self.source / "home"
        (directory / "dot_rendered.tmpl").write_text('{{ fail "must not render" }}\n')
        (directory / "modify_dot_modified").write_text("#!/bin/sh\nexit 79\n")
        (directory / "create_dot_once").write_text("create-only\n")
        (directory / "literal_modify_name").write_text("ordinary literal name\n")
        self._native("apply", str(self.destination / "modify_name"))
        result = self._guard("--check")
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in (".rendered", ".modified", ".once"):
            self.assertEqual(self._guard(name).returncode, 2)

    def test_external_and_encrypted_files_are_not_read(self) -> None:
        marker = self.root / "gpg-invoked"
        encryptor = self.root / "fake-gpg"
        encryptor.write_text(f"#!/bin/sh\n: > {shlex.quote(str(marker))}\nexit 79\n")
        encryptor.chmod(0o755)
        with self.configuration.open("a") as stream:
            stream.write(
                f'encryption="gpg"\n[gpg]\ncommand={json.dumps(str(encryptor))}\n'
            )
        (self.source / "home/encrypted_dot_hidden.asc").write_bytes(
            b"not real ciphertext"
        )
        (self.source / "home/.chezmoiexternal.toml").write_text(
            '[".external"]\ntype="file"\nurl="https://example.invalid/not-fetched"\n'
        )
        result = self._guard("--check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(marker.exists())
        self.assertFalse((self.destination / ".external").exists())

    def test_ambiguous_source_hardlinks_block(self) -> None:
        self.second.write_bytes(self.first.read_bytes())
        self._native("apply", str(self.destination / ".second"))
        self.second.unlink()
        os.link(self.first, self.second)
        self.assertEqual(self._guard().returncode, 2)
        (self.destination / ".first").write_bytes(b"local edit\n")
        self.assertEqual(self._guard(".first").returncode, 2)

    @unittest.skipIf(os.geteuid() == 0, "root can read mode-zero files")
    def test_unreadable_live_file_blocks(self) -> None:
        target = self.destination / ".first"
        target.chmod(0)
        try:
            self.assertEqual(self._guard(".first").returncode, 2)
        finally:
            target.chmod(0o644)

    @unittest.skipUnless(GIT, "Git is needed to exercise committed source edits")
    def test_git_cleanliness_is_not_the_capture_oracle(self) -> None:
        assert GIT is not None

        def git(*arguments: str) -> None:
            subprocess.run(
                [
                    GIT,
                    "-c",
                    "user.name=Capture fixture",
                    "-c",
                    "user.email=capture@example.invalid",
                    "-c",
                    "commit.gpgsign=false",
                    *arguments,
                ],
                cwd=self.source,
                env=self.environment,
                capture_output=True,
                check=True,
                timeout=30,
            )

        git("init", "--quiet")
        git("add", "--all")
        git("commit", "-m", "test: establish fixture")

        (self.source / "unrelated-notes").write_text("unrelated dirty file\n")
        (self.destination / ".first").write_bytes(b"local edit\n")
        self.assertEqual(self._guard(".first").returncode, 0)
        (self.destination / ".first").write_bytes(b"second local edit before commit\n")
        self.assertEqual(self._guard(".first").returncode, 0)

        self.second.write_bytes(b"uncommitted source edit\n")
        self.assertEqual(self._guard(".second").returncode, 2)
        git("add", "--all")
        git("commit", "-m", "test: commit source without applying")
        self.assertEqual(self._guard(".second").returncode, 2)

    def test_native_git_automation_and_mutation_hooks_block(self) -> None:
        initial = self.configuration.read_text()
        for extra in (
            "[git]\nautoCommit=true\n",
            '[hooks.re-add.pre]\ncommand="/bin/true"\n',
        ):
            self.configuration.write_text(initial + extra)
            self.assertEqual(self._guard().returncode, 2)

    def test_destination_alias_does_not_reuse_another_state_key(self) -> None:
        alias = self.root / "destination-alias"
        alias.symlink_to(self.destination, target_is_directory=True)
        self.configuration.write_text(
            self.configuration.read_text().replace(str(self.destination), str(alias))
        )
        self.assertEqual(self._guard(".first").returncode, 2)

    def test_changed_preflight_input_prevents_capture(self) -> None:
        (self.destination / ".first").write_bytes(b"local edit\n")
        original = capture._Chezmoi.run
        reads = 0
        captures = 0

        def change(native: capture._Chezmoi, *arguments: str) -> bytes:
            nonlocal reads, captures
            if arguments[0] == "dump-config":
                reads += 1
                if reads == 2:
                    self.first.write_bytes(b"intervening source edit\n")
            if arguments[0] == "re-add":
                captures += 1
            return original(native, *arguments)

        with patch.object(capture._Chezmoi, "run", change):
            self.assertEqual(self._in_process(".first"), 2)
        self.assertEqual(captures, 0)
        self.assertEqual(self.first.read_bytes(), b"intervening source edit\n")

    def test_partial_native_failure_does_not_rollback_or_retry(self) -> None:
        for name in (".first", ".second"):
            (self.destination / name).write_bytes(b"local edit\n")
        original = capture._Chezmoi.run
        captures = 0

        def fail(native: capture._Chezmoi, *arguments: str) -> bytes:
            nonlocal captures
            if arguments[0] == "re-add":
                captures += 1
                split = arguments.index("--") + 1
                original(native, *arguments[:split], arguments[split])
                raise capture._Failure("injected native capture failure")
            return original(native, *arguments)

        with patch.object(capture._Chezmoi, "run", fail):
            self.assertEqual(self._in_process(".first", ".second"), 1)
        self.assertEqual(captures, 1)
        self.assertEqual(self.first.read_bytes(), b"local edit\n")
        self.assertEqual(self.second.read_bytes(), b"second original\n")

    def test_failed_postcheck_preserves_the_observed_changes(self) -> None:
        (self.destination / ".first").write_bytes(b"local edit\n")
        original = capture._Chezmoi.run

        def change(native: capture._Chezmoi, *arguments: str) -> bytes:
            result = original(native, *arguments)
            if arguments[0] == "re-add":
                self.first.write_bytes(b"post-capture source change\n")
            return result

        with patch.object(capture._Chezmoi, "run", change):
            self.assertEqual(self._in_process(".first"), 1)
        self.assertEqual(self.first.read_bytes(), b"post-capture source change\n")


if __name__ == "__main__":
    unittest.main()
