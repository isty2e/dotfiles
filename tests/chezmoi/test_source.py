import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
VIM_SOURCE = REPO / "home/dot_vimrc"
NVIM_SOURCE = REPO / "home/private_dot_config/nvim"
HELIX_SOURCE = REPO / "home/private_dot_config/helix"
ZED_SOURCE = REPO / "home/private_dot_config/zed"
_configured_chezmoi = os.environ.get("CHEZMOI")
_selected_chezmoi = (
    shutil.which(_configured_chezmoi or "chezmoi") or _configured_chezmoi
)
CHEZMOI = (
    str(Path(_selected_chezmoi).expanduser().resolve()) if _selected_chezmoi else None
)


@unittest.skipUnless(CHEZMOI, "chezmoi is required; set CHEZMOI to its executable")
class ChezmoiSourceTests(unittest.TestCase):
    def test_private_config_mode_survives_repeated_apply(self) -> None:
        self._chezmoi("apply")
        config = self.destination / ".config"
        self.assertEqual(stat.S_IMODE(config.stat().st_mode), 0o700)

        self._chezmoi("apply")
        self._chezmoi("verify")
        self.assertEqual(stat.S_IMODE(config.stat().st_mode), 0o700)

    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="chezmoi vim ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.home = self.root / "process home"
        self.destination = self.root / "destination"
        self.former = self.root / "former source"
        for directory in (self.home, self.destination, self.former, self.root / "tmp"):
            directory.mkdir()
        self.sources = {Path(".vimrc"): VIM_SOURCE}
        for name, source in (
            ("nvim", NVIM_SOURCE),
            ("helix", HELIX_SOURCE),
            ("zed", ZED_SOURCE),
        ):
            self.sources.update(
                (Path(".config") / name / path.relative_to(source), path)
                for path in source.rglob("*")
                if path.is_file()
            )

        self.environment = {
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_CACHE_HOME": str(self.home / ".cache"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "XDG_STATE_HOME": str(self.home / ".local/state"),
            "TMPDIR": str(self.root / "tmp"),
            "PATH": os.defpath,
            "SHELL": "/bin/sh",
            "LANG": "en_US.UTF-8",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
        }

    def _chezmoi(self, *arguments: str) -> str:
        assert CHEZMOI is not None
        result = subprocess.run(
            [
                CHEZMOI,
                "--source",
                str(REPO),
                "--destination",
                str(self.destination),
                "--no-tty",
                "--no-pager",
                *arguments,
            ],
            env=self.environment,
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def test_only_editor_configuration_files_are_managed(self) -> None:
        managed = self._chezmoi("managed", "--include=files", "--path-style=relative")
        expected = {path.as_posix() for path in self.sources}
        self.assertEqual(set(managed.splitlines()), expected)

    def test_apply_replaces_config_links_and_preserves_unmanaged_state(self) -> None:
        old_config = self.former / "vimrc"
        old_config.write_bytes(b'" former Vim configuration\n')
        old_runtime = self.former / "vim"
        old_runtime.mkdir()
        marker = old_runtime / "existing-plugin"
        marker.write_bytes(b"former runtime")
        config = self.destination / ".vimrc"
        runtime = self.destination / ".vim"
        config.symlink_to(old_config)
        runtime.symlink_to(old_runtime, target_is_directory=True)

        old_nvim = self.former / "nvim-init.lua"
        old_nvim.write_bytes(b"-- former Neovim configuration\n")
        nvim = self.destination / ".config/nvim"
        nvim.mkdir(parents=True)
        nvim_init = nvim / "init.lua"
        nvim_init.symlink_to(old_nvim)
        metadata = nvim / ".git"
        metadata.mkdir()
        repository_marker = metadata / "preserved"
        repository_marker.write_bytes(b"existing repository metadata")

        self.assertTrue(self._chezmoi("diff").strip())
        self.assertTrue(config.is_symlink())
        self.assertEqual(old_config.read_bytes(), b'" former Vim configuration\n')
        self._chezmoi("apply")
        self.assertFalse(config.is_symlink())
        self.assertEqual(config.read_bytes(), VIM_SOURCE.read_bytes())
        self.assertEqual(old_config.read_bytes(), b'" former Vim configuration\n')
        self.assertFalse(nvim_init.is_symlink())
        self.assertEqual(old_nvim.read_bytes(), b"-- former Neovim configuration\n")
        for target, source in self.sources.items():
            self.assertEqual(
                (self.destination / target).read_bytes(), source.read_bytes()
            )
        self.assertTrue(runtime.is_symlink())
        self.assertEqual(os.readlink(runtime), str(old_runtime))
        self.assertEqual(marker.read_bytes(), b"former runtime")
        self.assertEqual(
            repository_marker.read_bytes(), b"existing repository metadata"
        )

        runtime.unlink()
        runtime.mkdir()
        local_state = runtime / "installed-plugin"
        local_state.write_bytes(b"local runtime")
        self._chezmoi("apply")
        self.assertFalse(runtime.is_symlink())
        self.assertEqual(local_state.read_bytes(), b"local runtime")
        self.assertEqual(marker.read_bytes(), b"former runtime")
        self._chezmoi("verify")

        preserved_runtime = self.root / "runtime after rollback"
        runtime.rename(preserved_runtime)
        config.unlink()
        config.symlink_to(old_config)
        runtime.symlink_to(old_runtime, target_is_directory=True)
        self.assertEqual(config.read_bytes(), b'" former Vim configuration\n')
        self.assertEqual(
            (preserved_runtime / "installed-plugin").read_bytes(), b"local runtime"
        )
        self.assertEqual(marker.read_bytes(), b"former runtime")
        self.assertTrue(self._chezmoi("diff").strip())

    def test_helix_directory_handoff_preserves_unmanaged_grammars(self) -> None:
        old = self.former / "helix"
        grammar = old / "runtime/grammars/python.so"
        grammar.parent.mkdir(parents=True)
        grammar.write_bytes(b"existing native grammar")
        old_config = old / "config.toml"
        old_config.write_bytes(b'theme = "former"\n')
        target = self.destination / ".config/helix"
        target.parent.mkdir(parents=True)
        target.symlink_to(old, target_is_directory=True)

        self.assertTrue(self._chezmoi("diff").strip())
        self.assertTrue(target.is_symlink())
        self._chezmoi("apply")
        self.assertFalse(target.is_symlink())
        self.assertEqual(old_config.read_bytes(), b'theme = "former"\n')
        self.assertEqual(grammar.read_bytes(), b"existing native grammar")

        runtime = old / "runtime"
        runtime.rename(target / "runtime")
        self._chezmoi("apply")
        self._chezmoi("verify")
        self.assertEqual(
            (target / "runtime/grammars/python.so").read_bytes(),
            b"existing native grammar",
        )

        preserved = self.root / "new helix configuration"
        target.rename(preserved)
        (preserved / "runtime").rename(old / "runtime")
        target.symlink_to(old, target_is_directory=True)
        self.assertEqual(target.readlink(), old)
        self.assertEqual(grammar.read_bytes(), b"existing native grammar")
        self.assertEqual(
            (preserved / "config.toml").read_bytes(),
            (HELIX_SOURCE / "config.toml").read_bytes(),
        )

    def test_zed_files_preserve_former_keymap_and_unmanaged_state(self) -> None:
        old_keymap = self.former / "zed-keymap.json"
        old_keymap.write_bytes(b"[]\n")
        target = self.destination / ".config/zed"
        target.mkdir(parents=True)
        keymap = target / "keymap.json"
        keymap.symlink_to(old_keymap)
        settings = target / "settings.json"
        settings.write_bytes(b'{"theme": "former"}\n')
        state = target / "native-state"
        state.write_bytes(b"unmanaged editor state")

        self.assertTrue(self._chezmoi("diff").strip())
        self.assertTrue(keymap.is_symlink())
        self.assertEqual(settings.read_bytes(), b'{"theme": "former"}\n')
        self._chezmoi("apply")
        self.assertFalse(keymap.is_symlink())
        for name in ("keymap.json", "settings.json"):
            self.assertEqual(
                (target / name).read_bytes(), (ZED_SOURCE / name).read_bytes()
            )
        self.assertEqual(old_keymap.read_bytes(), b"[]\n")
        self.assertEqual(state.read_bytes(), b"unmanaged editor state")

        self._chezmoi("apply")
        self._chezmoi("verify")
        self.assertEqual(state.read_bytes(), b"unmanaged editor state")


if __name__ == "__main__":
    unittest.main()
