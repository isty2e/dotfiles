import json
import os
import shutil
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path
from typing import TypedDict, cast

SOURCE = Path(__file__).resolve().parents[2] / "workspaces/mise/config.toml"
MISE = os.environ.get("MISE")


class _LoadedConfig(TypedDict):
    path: str
    tools: list[str]


class _SelectedTool(TypedDict):
    requested_version: str
    installed: bool


@unittest.skipUnless(MISE, "set MISE to the actual mise executable")
class MiseConfigTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="mise config ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.home = self.root / "home"
        self.target = self.home / ".config/mise/config.toml"
        self.target.parent.mkdir(parents=True)
        (self.root / "tmp").mkdir()
        shutil.copyfile(SOURCE, self.target)
        self.environment = {
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_CACHE_HOME": str(self.home / ".cache"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "XDG_STATE_HOME": str(self.home / ".local/state"),
            "MISE_DATA_DIR": str(self.home / ".local/share/mise"),
            "MISE_CACHE_DIR": str(self.home / ".cache/mise"),
            "MISE_STATE_DIR": str(self.home / ".local/state/mise"),
            "MISE_OFFLINE": "true",
            "TMPDIR": str(self.root / "tmp"),
            "PATH": os.defpath,
        }

    def test_native_read_loads_declared_tools_without_changing_source(self) -> None:
        assert MISE is not None
        expected: set[str] = set(tomllib.loads(SOURCE.read_text())["tools"])
        for _ in range(2):
            result = subprocess.run(
                [MISE, "config", "ls", "--json"],
                env=self.environment,
                cwd=self.home,
                capture_output=True,
                text=True,
                check=False,
                timeout=30,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            configs = cast(list[_LoadedConfig], json.loads(result.stdout))
            matching = [
                config for config in configs if config["path"] == str(self.target)
            ]
            self.assertEqual(len(matching), 1)
            self.assertEqual(set(matching[0]["tools"]), expected)
            self.assertEqual(self.target.read_bytes(), SOURCE.read_bytes())

    def test_project_rust_toolchain_overrides_global_without_installing(self) -> None:
        assert MISE is not None
        project = self.home / "project"
        project.mkdir()
        (project / "rust-toolchain.toml").write_text(
            '[toolchain]\nchannel = "1.85.0"\n'
        )
        result = subprocess.run(
            [MISE, "ls", "rust", "--current", "--json"],
            env=self.environment,
            cwd=project,
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        selected = cast(list[_SelectedTool], json.loads(result.stdout))
        self.assertEqual(len(selected), 1)
        self.assertEqual(selected[0]["requested_version"], "1.85.0")
        self.assertFalse(selected[0]["installed"])
        self.assertEqual(self.target.read_bytes(), SOURCE.read_bytes())

    def test_native_global_edit_writes_through_directory_binding(self) -> None:
        assert MISE is not None
        workspace = self.root / "checkout/workspaces/mise"
        workspace.parent.mkdir(parents=True)
        self.target.parent.rename(workspace)
        self.target.parent.symlink_to(workspace, target_is_directory=True)
        result = subprocess.run(
            [MISE, "use", "--global", "--remove", "node"],
            env=self.environment,
            cwd=self.home,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn(
            "node", tomllib.loads((workspace / "config.toml").read_text())["tools"]
        )
        self.assertTrue(self.target.parent.is_symlink())
        self.assertFalse((self.home / ".local/share/mise/installs").exists())


if __name__ == "__main__":
    unittest.main()
