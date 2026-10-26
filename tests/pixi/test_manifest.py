import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "home/pixi-env/base/pixi.toml"
PIXI = os.environ.get("PIXI")


@unittest.skipUnless(PIXI, "set PIXI to a Pixi 0.81+ executable, not a manager shim")
class PixiManifestTests(unittest.TestCase):
    def test_native_metadata_read_preserves_manifest_without_installing(self) -> None:
        assert PIXI is not None
        with tempfile.TemporaryDirectory(prefix="pixi manifest ") as temporary:
            root = Path(temporary).resolve()
            home = root / "home"
            home.mkdir()
            (root / "tmp").mkdir()
            manifest = root / "pixi.toml"
            shutil.copyfile(SOURCE, manifest)
            expected = manifest.read_bytes()
            environment = {
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(home / ".config"),
                "XDG_CACHE_HOME": str(home / ".cache"),
                "XDG_DATA_HOME": str(home / ".local/share"),
                "XDG_STATE_HOME": str(home / ".local/state"),
                "TMPDIR": str(root / "tmp"),
                "PATH": os.defpath,
            }

            for _ in range(2):
                result = subprocess.run(
                    [
                        PIXI,
                        "workspace",
                        "environment",
                        "list",
                        "--manifest-path",
                        str(manifest),
                    ],
                    env=environment,
                    cwd=root,
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=30,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(manifest.read_bytes(), expected)
                self.assertFalse((root / ".pixi/envs/default").exists())


if __name__ == "__main__":
    unittest.main()
