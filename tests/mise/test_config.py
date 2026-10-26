import json
import os
import shutil
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path
from typing import TypedDict, cast

SOURCE = (
    Path(__file__).resolve().parents[2] / "home/private_dot_config/mise/config.toml"
)
MISE = os.environ.get("MISE")


class _LoadedConfig(TypedDict):
    path: str
    tools: list[str]


@unittest.skipUnless(MISE, "set MISE to the actual mise executable")
class MiseConfigTests(unittest.TestCase):
    def test_native_read_loads_declared_tools_without_changing_source(self) -> None:
        assert MISE is not None
        expected = cast(dict[str, str], tomllib.loads(SOURCE.read_text())["tools"])
        with tempfile.TemporaryDirectory(prefix="mise config ") as temporary:
            root = Path(temporary).resolve()
            home = root / "home"
            target = home / ".config/mise/config.toml"
            target.parent.mkdir(parents=True)
            (root / "tmp").mkdir()
            shutil.copyfile(SOURCE, target)
            environment = {
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(home / ".config"),
                "XDG_CACHE_HOME": str(home / ".cache"),
                "XDG_DATA_HOME": str(home / ".local/share"),
                "XDG_STATE_HOME": str(home / ".local/state"),
                "MISE_DATA_DIR": str(home / ".local/share/mise"),
                "MISE_CACHE_DIR": str(home / ".cache/mise"),
                "MISE_STATE_DIR": str(home / ".local/state/mise"),
                "TMPDIR": str(root / "tmp"),
                "PATH": os.defpath,
            }

            for _ in range(2):
                result = subprocess.run(
                    [MISE, "config", "ls", "--json"],
                    env=environment,
                    cwd=home,
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=30,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                configs = cast(list[_LoadedConfig], json.loads(result.stdout))
                matching = [
                    config for config in configs if config["path"] == str(target)
                ]
                self.assertEqual(len(matching), 1)
                self.assertEqual(set(matching[0]["tools"]), set(expected))
                self.assertEqual(target.read_bytes(), SOURCE.read_bytes())


if __name__ == "__main__":
    unittest.main()
