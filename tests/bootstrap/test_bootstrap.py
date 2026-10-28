import json
import os
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import tomllib

REPO = Path(__file__).resolve().parents[2]
CHEZMOI = shutil.which(os.environ.get("CHEZMOI", "chezmoi"))
GIT = shutil.which("git")


class _BootstrapTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="bootstrap '$ ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.home = self.root / "home '$"
        self.home.mkdir()
        self.repo = self.root / "checkout '$"
        self.repo.mkdir()
        shutil.copyfile(REPO / "bootstrap.sh", self.repo / "bootstrap.sh")
        shutil.copyfile(REPO / ".chezmoiroot", self.repo / ".chezmoiroot")
        shutil.copytree(REPO / "home", self.repo / "home")
        self.utilities = self.root / "utilities"
        self.utilities.mkdir()
        for name in (
            "dirname",
            "mktemp",
            "rm",
            "mkdir",
            "sh",
            "cp",
            "ln",
            "mv",
            "rmdir",
            "cat",
        ):
            executable = shutil.which(name)
            assert executable is not None
            (self.utilities / name).symlink_to(executable)
        (self.root / "tmp").mkdir()
        self.environment = {
            "HOME": str(self.home),
            "PATH": str(self.utilities),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_CACHE_HOME": str(self.home / ".cache"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "XDG_STATE_HOME": str(self.home / ".local/state"),
            "TMPDIR": str(self.root / "tmp"),
            "SHELL": "/bin/sh",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
        }
        self.chezmoi = self.home / "chezmoi-executable"
        self.chezmoi.write_text(
            '#!/bin/sh\n[ "${1-}" != --version ] || exit 0\n'
            ': > "$HOME/chezmoi-queried"\nexit 17\n'
        )
        self.chezmoi.chmod(0o755)
        mise = self.home / "mise-executable"
        mise.write_text(
            "#!/bin/sh\nset -eu\n"
            '[ "${1-}" != --version ] || exit 0\n'
            '[ -f "$MISE_GLOBAL_CONFIG_FILE" ]\n'
            'if [ "${3-}" = which ] && [ "${4-}" = sheldon ]; then\n'
            '  [ "$1" = --cd ] && [ "$2" = "$HOME" ]\n'
            '  [ "$MISE_NOT_FOUND_AUTO_INSTALL" = false ]\n'
            '  [ "$MISE_AUTO_INSTALL" = false ]\n'
            '  printf "%s\\n" "$HOME/sheldon-executable"\n'
            "  exit 0\n"
            "fi\n"
            'printf "%s\\n" "$MISE_GLOBAL_CONFIG_FILE" "$@" >> "$HOME/mise-calls"\n'
            '[ ! -f "$HOME/fail-mise" ]\n'
        )
        mise.chmod(0o755)
        sheldon = self.home / "sheldon-executable"
        sheldon.write_text(
            "#!/bin/sh\nset -eu\n"
            '[ "$1" = --config-file ] && [ -f "$2" ]\n'
            '[ "$3" = --data-dir ] && [ -d "$4" ]\n'
            "shift 4\n"
            '[ "${1-}" != --quiet ] || shift\n'
            'printf "%s\\n" "$1" >> "$HOME/sheldon-calls"\n'
            'case $1 in lock) ;; source) printf "%s\\n" "# prepared" ;; *) exit 1 ;; esac\n'
        )
        sheldon.chmod(0o755)
        (self.home / "install-chezmoi.sh").write_text(
            "set -eu\n"
            'printf "%s\\n" chezmoi >> "$HOME/installers"\n'
            '[ ! -f "$HOME/fail-installer" ] || exit 19\n'
            '[ "$1" = -b ]\n'
            'ln -s "$HOME/chezmoi-executable" "$2/chezmoi"\n'
        )
        (self.home / "install-mise.sh").write_text(
            "set -eu\n"
            'printf "%s\\n" mise >> "$HOME/installers"\n'
            'ln -s "$HOME/mise-executable" "$MISE_INSTALL_PATH"\n'
        )
        curl = self.utilities / "curl"
        curl.write_text(
            "#!/bin/sh\nset -eu\n"
            'while [ "$#" -gt 0 ]; do\n'
            "  case $1 in\n"
            "    -o) output=$2; shift 2 ;;\n"
            "    https://*) url=$1; shift ;;\n"
            "    *) shift ;;\n"
            "  esac\n"
            "done\n"
            'printf "%s\\n" "$url" >> "$HOME/downloads"\n'
            'if [ -f "$HOME/fail-download" ]; then\n'
            '  printf \': > "$HOME/partial-executed"\\n\' > "$output"\n'
            "  exit 22\n"
            "fi\n"
            "case $url in\n"
            '  https://get.chezmoi.io) cp "$HOME/install-chezmoi.sh" "$output" ;;\n'
            '  https://mise.run) cp "$HOME/install-mise.sh" "$output" ;;\n'
            "  *) exit 23 ;;\n"
            "esac\n"
        )
        curl.chmod(0o755)

    def _run_bootstrap(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["/bin/sh", str(self.repo / "bootstrap.sh"), *arguments],
            cwd=self.root,
            env=self.environment,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )


class BootstrapAcquisitionTests(_BootstrapTests):
    def test_help_does_not_prepare_or_download_tools(self) -> None:
        result = self._run_bootstrap("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / "downloads").exists())
        self.assertFalse((self.home / ".local").exists())

    def test_acquisition_precedes_handoff_and_reuses_installed_tools(self) -> None:
        result = self._run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.home / "chezmoi-queried").exists())
        downloads = self.home / "downloads"
        self.assertEqual(
            downloads.read_text().splitlines(),
            ["https://get.chezmoi.io", "https://mise.run"],
        )
        self.assertEqual(
            (self.home / "installers").read_text().splitlines(), ["chezmoi", "mise"]
        )
        initial = downloads.read_bytes()
        result = self._run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(downloads.read_bytes(), initial)
        self.assertEqual(list((self.root / "tmp").iterdir()), [])

    def test_failed_download_is_not_executed(self) -> None:
        (self.home / "fail-download").touch()
        result = self._run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / "installers").exists())
        self.assertFalse((self.home / "partial-executed").exists())
        self.assertEqual(
            (self.home / "downloads").read_text().splitlines(),
            ["https://get.chezmoi.io"],
        )
        self.assertEqual(list((self.root / "tmp").iterdir()), [])

    def test_failed_installer_stops_before_other_acquisition(self) -> None:
        (self.home / "fail-installer").touch()
        result = self._run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(
            (self.home / "installers").read_text().splitlines(), ["chezmoi"]
        )
        self.assertFalse((self.home / "mise-calls").exists())
        self.assertFalse((self.home / "chezmoi-queried").exists())
        self.assertEqual(list((self.root / "tmp").iterdir()), [])


class BootstrapInvocationTests(_BootstrapTests):
    def setUp(self) -> None:
        super().setUp()
        source = shlex.quote(str(self.repo / "home"))
        self.chezmoi.write_text(
            "#!/bin/sh\nset -eu\n"
            '[ "${1-}" != --version ] || exit 0\n'
            'if [ "$1" = execute-template ]; then\n'
            '  printf "%s\\n" "$HOME/.config/chezmoi/chezmoi.toml"\n'
            'elif [ "$1" = source-path ] || { [ "$1" = --source ] && '
            '[ "${3-}" = source-path ]; }; then\n'
            f'  printf "%s\\n" {source}\n'
            "else\n"
            '  printf "%s\\n" "$@" > "$HOME/apply-arguments"\n'
            '  : > "$HOME/partial-placement"\n'
            '  exit "${BOOTSTRAP_FAKE_STATUS:-0}"\n'
            "fi\n"
        )

    def test_unconfigured_handoff_uses_guarded_init(self) -> None:
        result = self._run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            (self.home / "apply-arguments").read_text().splitlines(),
            [
                "--source",
                str(self.repo),
                "init",
                "--apply",
                "--less-interactive",
                "--error-on-conflict",
            ],
        )

    def test_configured_handoff_uses_guarded_apply(self) -> None:
        config = self.home / ".config/chezmoi/chezmoi.toml"
        config.parent.mkdir(parents=True)
        config.touch()

        result = self._run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            (self.home / "apply-arguments").read_text().splitlines(),
            ["apply", "--less-interactive", "--error-on-conflict"],
        )

    def test_failed_apply_preserves_status_and_reports_manual_recovery(self) -> None:
        config = self.home / ".config/chezmoi/chezmoi.toml"
        self.environment["BOOTSTRAP_FAKE_STATUS"] = "29"
        for configured in (False, True):
            with self.subTest(configured=configured):
                if configured:
                    config.parent.mkdir(parents=True)
                    config.touch()
                result = self._run_bootstrap()
                self.assertEqual(result.returncode, 29)
                self.assertTrue((self.home / "partial-placement").is_file())
                self.assertNotIn("chezmoi apply completed.", result.stdout)
                self.assertIn("chezmoi diff", result.stderr)
                self.assertIn("chezmoi apply --less-interactive", result.stderr)


@unittest.skipUnless(CHEZMOI and GIT, "chezmoi and git are required for native setup")
class BootstrapNativeTests(_BootstrapTests):
    def setUp(self) -> None:
        super().setUp()
        assert CHEZMOI is not None and GIT is not None
        self.chezmoi.unlink()
        self.chezmoi.symlink_to(Path(CHEZMOI).resolve())
        subprocess.run(
            [GIT, "init", "-q", str(self.repo)],
            env=self.environment,
            check=True,
            capture_output=True,
            timeout=30,
        )
        git = self.utilities / "git"
        git.write_text(
            "#!/bin/sh\nset -eu\n"
            'if [ "$1" = clone ]; then\n'
            '  printf "%s\\n" "$3" >> "$HOME/git-clones"\n'
            '  mkdir -p "$4/.git"\n'
            '  printf "%s\\n" "$3" > "$4/.git/origin"\n'
            'elif [ "$1" = -C ] && [ "${3:-}" = config ] && '
            '[ "${4:-}" = --get ] && [ "${5:-}" = remote.origin.url ]; then\n'
            '  cat "$2/.git/origin"\n'
            "else\n"
            f'  exec {shlex.quote(GIT)} "$@"\n'
            "fi\n"
        )
        git.chmod(0o755)

    def test_fresh_setup_persists_checkout_and_invokes_native_apply(self) -> None:
        result = self._run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        config = self.home / ".config/chezmoi/chezmoi.toml"
        self.assertEqual(tomllib.loads(config.read_text())["sourceDir"], str(self.repo))
        self.assertEqual(
            (self.home / ".config/mise/config.toml").read_bytes(),
            (REPO / "home/private_dot_config/mise/config.toml").read_bytes(),
        )
        self.assertEqual(
            (self.home / "mise-calls").read_text().splitlines()[0],
            str(self.home / ".config/mise/config.toml"),
        )
        self.assertCountEqual(
            (self.home / "mise-calls").read_text().splitlines()[1:],
            ["--cd", str(self.home), "install"],
        )
        self.assertFalse((self.home / ".local/share/chezmoi/.git").exists())
        self.assertEqual(
            (self.home / "sheldon-calls").read_text().splitlines(), ["lock", "source"]
        )
        state = self.home / ".local/share/dotfiles/sheldon"
        generation = (state / "current").read_text().strip()
        self.assertTrue(
            (state / "generations" / generation / "zsh-plugins.zsh").is_file()
        )

    def test_same_checkout_reuses_config_without_dropping_existing_settings(
        self,
    ) -> None:
        first = self._run_bootstrap()
        self.assertEqual(first.returncode, 0, first.stderr)
        config = self.home / ".config/chezmoi/chezmoi.toml"
        config.write_text(config.read_text() + '\n[data]\nkeep = "yes"\n')
        original = config.read_bytes()
        calls = (self.home / "mise-calls").read_bytes()

        result = self._run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(config.read_bytes(), original)
        self.assertEqual((self.home / "mise-calls").read_bytes(), calls)

    def test_conflicting_binding_preserves_config_and_does_not_apply(self) -> None:
        other = self.root / "another checkout"
        other.mkdir()
        config = self.home / ".config/chezmoi/chezmoi.toml"
        config.parent.mkdir(parents=True)
        original = f'sourceDir = {json.dumps(str(other))}\n[data]\nkeep = "yes"\n'
        config.write_text(original)

        result = self._run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(config.read_text(), original)
        self.assertFalse((self.home / "mise-calls").exists())
        self.assertFalse((self.home / ".vimrc").exists())

    def test_existing_providers_are_reused_without_installing_local_copies(
        self,
    ) -> None:
        (self.utilities / "chezmoi").symlink_to(self.chezmoi)
        (self.utilities / "mise").symlink_to(self.home / "mise-executable")
        result = self._run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / "downloads").exists())
        self.assertFalse((self.home / ".local/bin/chezmoi").exists())
        self.assertFalse((self.home / ".local/bin/mise").exists())
        self.assertTrue((self.home / "mise-calls").is_file())

    def test_failed_first_apply_resumes_with_the_persisted_binding(self) -> None:
        failure = self.home / "fail-mise"
        failure.touch()
        result = self._run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        config = self.home / ".config/chezmoi/chezmoi.toml"
        original = config.read_bytes()
        calls = (self.home / "mise-calls").read_bytes()
        failure.unlink()

        result = self._run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(config.read_bytes(), original)
        self.assertEqual((self.home / "mise-calls").read_bytes(), calls * 2)

    def test_existing_file_is_preserved_during_init_and_bound_retry(self) -> None:
        target = self.home / ".zshrc"
        original = b"existing private startup configuration\n"
        target.write_bytes(original)

        for _ in range(2):
            result = self._run_bootstrap()
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.read_bytes(), original)
            self.assertNotIn("chezmoi apply completed.", result.stdout)
            self.assertFalse((self.home / "mise-calls").exists())
            self.assertFalse((self.home / "sheldon-calls").exists())
            self.assertTrue((self.home / ".config/chezmoi/chezmoi.toml").is_file())

    def test_existing_config_directory_permissions_require_review(self) -> None:
        config_directory = self.home / ".config"
        config_directory.mkdir(mode=0o755)
        config_directory.chmod(0o755)

        result = self._run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(config_directory.stat().st_mode & 0o777, 0o755)
        self.assertFalse((self.home / "mise-calls").exists())

    def test_adopted_live_edit_is_preserved(self) -> None:
        result = self._run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stderr)
        target = self.home / ".zshrc"
        target.write_bytes(b"uncaptured local edit\n")
        calls = (self.home / "mise-calls").read_bytes()

        result = self._run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(target.read_bytes(), b"uncaptured local edit\n")
        self.assertEqual((self.home / "mise-calls").read_bytes(), calls)

    def test_newly_managed_existing_file_is_preserved(self) -> None:
        result = self._run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stderr)
        source = self.repo / "home/dot_existing"
        source.write_bytes(b"new repository declaration\n")
        target = self.home / ".existing"
        target.write_bytes(b"existing local value\n")

        result = self._run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(target.read_bytes(), b"existing local value\n")
        self.assertEqual(source.read_bytes(), b"new repository declaration\n")


if __name__ == "__main__":
    unittest.main()
