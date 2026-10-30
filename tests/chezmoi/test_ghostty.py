import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "home/private_dot_config/ghostty"
CHEZMOI = shutil.which(os.environ.get("CHEZMOI", "chezmoi"))
GHOSTTY = shutil.which(os.environ.get("GHOSTTY", "ghostty"))


@unittest.skipUnless(CHEZMOI, "chezmoi is required for Ghostty placement")
class GhosttyPlacementTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="ghostty placement ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "source"
        shutil.copytree(SOURCE, self.source / "private_dot_config/ghostty")
        self.destination = self.root / "destination"
        self.destination.mkdir()
        self.config = self.root / "chezmoi.toml"
        self.config.touch()
        process_home = self.root / "process-home"
        process_home.mkdir()
        self.environment = {
            "HOME": str(process_home),
            "PATH": os.defpath,
            "XDG_CONFIG_HOME": str(process_home / ".config"),
            "XDG_CACHE_HOME": str(process_home / ".cache"),
            "XDG_DATA_HOME": str(process_home / ".local/share"),
            "XDG_STATE_HOME": str(process_home / ".local/state"),
        }

    def _chezmoi(self, *arguments: str) -> None:
        assert CHEZMOI is not None
        subprocess.run(
            [
                CHEZMOI,
                "--source",
                str(self.source),
                "--destination",
                str(self.destination),
                "--config",
                str(self.config),
                "--less-interactive",
                "--error-on-conflict",
                *arguments,
            ],
            env=self.environment,
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def test_placement_preserves_unmanaged_themes_and_repeats(self) -> None:
        config = self.destination / ".config"
        config.mkdir(mode=0o700)
        ghostty = config / "ghostty"
        ghostty.mkdir(mode=0o755)
        themes = ghostty / "themes"
        themes.mkdir(mode=0o755)
        extra = themes / "local-preview"
        extra.write_text("background = 010203\n")

        self._chezmoi("apply")
        for path in SOURCE.rglob("*"):
            if path.is_file():
                self.assertEqual(
                    (ghostty / path.relative_to(SOURCE)).read_bytes(), path.read_bytes()
                )
        self._chezmoi("verify")
        self._chezmoi("apply")
        self._chezmoi("verify")
        self.assertEqual(extra.read_text(), "background = 010203\n")

    @unittest.skipUnless(GHOSTTY, "Ghostty is required for native config validation")
    def test_native_config_and_theme_validation(self) -> None:
        assert GHOSTTY is not None
        self._chezmoi("apply")
        ghostty = self.destination / ".config/ghostty"
        environment = self.environment | {
            "HOME": str(self.destination),
            "XDG_CONFIG_HOME": str(self.destination / ".config"),
        }
        for path in (ghostty / "config", *(ghostty / "themes").iterdir()):
            with self.subTest(path=path.name):
                subprocess.run(
                    [GHOSTTY, "+validate-config", f"--config-file={path}"],
                    env=environment,
                    capture_output=True,
                    text=True,
                    timeout=30,
                    check=True,
                )


if __name__ == "__main__":
    unittest.main()
