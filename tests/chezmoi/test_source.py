import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
VIM_SOURCE = REPO / "home/dot_vimrc"
_configured_chezmoi = os.environ.get("CHEZMOI")
_selected_chezmoi = (
    shutil.which(_configured_chezmoi or "chezmoi") or _configured_chezmoi
)
CHEZMOI = (
    str(Path(_selected_chezmoi).expanduser().resolve()) if _selected_chezmoi else None
)


@unittest.skipUnless(CHEZMOI, "chezmoi is required; set CHEZMOI to its executable")
class ChezmoiSourceTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="chezmoi vim ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.home = self.root / "process home"
        self.destination = self.root / "destination"
        self.former = self.root / "former source"
        for directory in (self.home, self.destination, self.former, self.root / "tmp"):
            directory.mkdir()
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

    def test_vim_is_the_only_managed_target(self) -> None:
        managed = self._chezmoi("managed", "--path-style=relative")
        self.assertEqual(managed.splitlines(), [".vimrc"])

    def test_apply_replaces_only_the_config_link_and_preserves_runtime(self) -> None:
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

        self.assertTrue(self._chezmoi("diff").strip())
        self.assertTrue(config.is_symlink())
        self.assertEqual(old_config.read_bytes(), b'" former Vim configuration\n')
        self._chezmoi("apply")
        self.assertFalse(config.is_symlink())
        self.assertEqual(config.read_bytes(), VIM_SOURCE.read_bytes())
        self.assertEqual(old_config.read_bytes(), b'" former Vim configuration\n')
        self.assertTrue(runtime.is_symlink())
        self.assertEqual(os.readlink(runtime), str(old_runtime))
        self.assertEqual(marker.read_bytes(), b"former runtime")

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


if __name__ == "__main__":
    unittest.main()
