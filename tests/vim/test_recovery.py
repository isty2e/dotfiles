import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().parent / "fixtures"
VIM = shutil.which("vim")
LATEST_MANAGER_URL = (
    "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
)


@unittest.skipUnless(VIM, "Vim is required for the configuration integration tests")
class VimTestCase(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="vim recovery ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.assets = self.root / "assets"
        self.assets.mkdir()
        self.vimrc = self.root / "standalone vimrc"
        source = Path(os.environ.get("VIMRC_UNDER_TEST", REPO / ".vimrc"))
        shutil.copyfile(source, self.vimrc)
        shutil.copyfile(FIXTURES / "plug.vim", self.assets / "plug.vim")
        for color in (REPO / ".vim/colors").glob("*.vim"):
            shutil.copyfile(color, self.assets / color.name)

        curl = self.bin / "curl"
        curl.write_text(f"#!{sys.executable}\n" + (FIXTURES / "curl.py").read_text())
        curl.chmod(0o755)
        git = self.bin / "git"
        git.write_text("#!/bin/sh\nexit 0\n")
        git.chmod(0o755)

        self.env = {
            "HOME": str(self.home),
            "PATH": str(self.bin),
            "SHELL": "/bin/sh",
            "LANG": "en_US.UTF-8",
            "TERM": "dumb",
            "CURL_LOG": str(self.root / "curl.jsonl"),
            "INSTALL_LOG": str(self.root / "install.log"),
            "ASSET_SOURCE": str(self.assets),
            "RESULT": str(self.root / "result.json"),
        }

    def _run_vim(self, commands: str) -> str:
        probe = self.root / "probe.vim"
        probe.write_text(
            "let g:result = {}\n"
            + commands
            + "\ncall writefile([json_encode(g:result)], $RESULT)\nqa!\n"
        )
        assert VIM is not None
        log = self.root / "vim.log"
        completed = subprocess.run(
            [
                VIM,
                "-Nu",
                str(self.vimrc),
                "-n",
                "-i",
                "NONE",
                "-es",
                "-V1" + str(log),
                "-S",
                str(probe),
            ],
            env=self.env,
            cwd=self.root,
            capture_output=True,
            check=False,
            text=True,
            timeout=30,
        )
        self.assertEqual(
            completed.returncode,
            0,
            completed.stdout
            + completed.stderr
            + (log.read_text() if log.exists() else ""),
        )
        return Path(self.env["RESULT"]).read_text()

    def _seed_manager(self, source: Path = FIXTURES / "plug.vim") -> None:
        target = self.home / ".vim/autoload/plug.vim"
        target.parent.mkdir(parents=True)
        shutil.copyfile(source, target)


class VimRecoveryTests(VimTestCase):
    def test_bare_startup_loads_core_without_installing(self) -> None:
        result = json.loads(
            self._run_vim("""
call setline(1, ['first', 'second', 'third'])
normal n
let g:result = [&number, &shiftwidth, &expandtab, line('.'), g:colors_name]
""")
        )
        self.assertEqual(result, [1, 2, 1, 2, "default"])
        self.assertFalse((self.home / ".vim").exists())
        self.assertFalse(Path(self.env["CURL_LOG"]).exists())
        self.assertFalse(Path(self.env["INSTALL_LOG"]).exists())

    def test_existing_manager_startup_does_not_refresh(self) -> None:
        self._seed_manager()
        manager = self.home / ".vim/autoload/plug.vim"
        original = manager.read_bytes()
        self._run_vim("")
        self.assertEqual(manager.read_bytes(), original)
        self.assertFalse(Path(self.env["CURL_LOG"]).exists())
        self.assertFalse(Path(self.env["INSTALL_LOG"]).exists())

    def test_filetype_indentation_does_not_leak_to_other_buffers(self) -> None:
        self._seed_manager()
        result = json.loads(
            self._run_vim("""
let g:result = []
for kind in ['python', 'ruby', 'html', 'rust', 'swift', 'text']
  enew!
  execute 'setfiletype ' . kind
  call add(g:result, [&softtabstop, &shiftwidth, &tabstop, &expandtab])
endfor
call add(g:result, [&g:softtabstop, &g:shiftwidth, &g:tabstop])
""")
        )
        self.assertEqual(result, [[4, 4, 4, 1]] + [[2, 2, 2, 1]] * 5 + [[2, 2, 2]])

    def test_setup_restores_assets_and_delegates_installation(self) -> None:
        for name in (".zshrc", ".bashrc"):
            (self.home / name).write_text("keep existing shell settings\n")
        result = json.loads(
            self._run_vim("""
VimSetup
VimSetup
let g:result = [g:plugs.fzf, len(g:plugs)]
""")
        )
        self.assertEqual(
            result,
            [
                {
                    "dir": str(self.home / ".vim/plugged/fzf"),
                    "uri": "junegunn/fzf",
                    "do": "./install --bin",
                },
                27,
            ],
        )
        downloads = [
            json.loads(line)
            for line in Path(self.env["CURL_LOG"]).read_text().splitlines()
        ]
        self.assertEqual(len(downloads), 5)
        self.assertEqual(
            [entry["url"] for entry in downloads if entry["url"].endswith("/plug.vim")],
            [LATEST_MANAGER_URL, LATEST_MANAGER_URL],
        )
        for downloaded in downloads:
            self.assertTrue(
                downloaded["url"].startswith("https://raw.githubusercontent.com/")
            )
            target = (
                self.home
                / ".vim"
                / (
                    "autoload/plug.vim"
                    if downloaded["url"].endswith("/plug.vim")
                    else "colors/" + downloaded["url"].rsplit("/", 1)[-1]
                )
            )
            self.assertEqual(
                target.read_bytes(), (self.assets / target.name).read_bytes()
            )
            self.assertFalse(Path(downloaded["output"]).exists())
        self.assertEqual(
            Path(self.env["INSTALL_LOG"]).read_text().splitlines(), ["--sync", "--sync"]
        )
        self.assertFalse((self.home / ".fzf").exists())
        self.assertFalse((self.home / ".vim/autoload/plug.vim.old").exists())
        for name in (".zshrc", ".bashrc"):
            self.assertEqual(
                (self.home / name).read_text(), "keep existing shell settings\n"
            )

    def test_existing_colors_and_plugin_tree_are_preserved(self) -> None:
        self._seed_manager()
        color = self.home / ".vim/colors/wombat256.vim"
        color.parent.mkdir()
        color.write_text('" locally customized color\n')
        plugin = self.home / ".vim/plugged/custom-plugin/local.vim"
        plugin.parent.mkdir(parents=True)
        plugin.write_text('" keep local plugin modifications\n')
        self._run_vim("VimSetup")
        self.assertEqual(color.read_text(), '" locally customized color\n')
        self.assertEqual(plugin.read_text(), '" keep local plugin modifications\n')
        self.assertEqual(len(Path(self.env["CURL_LOG"]).read_text().splitlines()), 3)

    def test_existing_manager_is_refreshed_and_reloaded_in_the_same_session(
        self,
    ) -> None:
        self._seed_manager()
        manager = self.home / ".vim/autoload/plug.vim"
        manager.write_text(
            manager.read_text() + "\nlet g:vim_test_manager_source = 'existing'\n"
        )
        result = json.loads(
            self._run_vim("""
let before = g:vim_test_manager_source
VimSetup
let g:result = [before, g:vim_test_manager_source]
""")
        )
        self.assertEqual(result, ["existing", "downloaded"])
        self.assertEqual(manager.read_bytes(), (self.assets / "plug.vim").read_bytes())

    def test_backup_tracks_only_the_previous_distinct_manager(self) -> None:
        self._seed_manager()
        manager = self.home / ".vim/autoload/plug.vim"
        backup = manager.with_name("plug.vim.old")
        provider = self.assets / "plug.vim"
        base = manager.read_bytes()
        original = base.rstrip(b"\n")
        manager.write_bytes(original)
        updated = base + b"\nlet g:vim_test_revision = 2\n"
        provider.write_bytes(updated)

        self._run_vim("VimSetup")
        self.assertEqual(manager.read_bytes(), updated)
        self.assertEqual(backup.read_bytes(), original)

        self._run_vim("VimSetup")
        self.assertEqual(manager.read_bytes(), updated)
        self.assertEqual(backup.read_bytes(), original)

        newest = base + b"\nlet g:vim_test_revision = 3\n"
        provider.write_bytes(newest)
        self._run_vim("VimSetup")
        self.assertEqual(manager.read_bytes(), newest)
        self.assertEqual(backup.read_bytes(), updated)
        self.assertEqual(list(manager.parent.glob("*.download-*")), [])

    def test_backup_publication_failure_does_not_replace_the_manager(self) -> None:
        self._seed_manager()
        manager = self.home / ".vim/autoload/plug.vim"
        original = manager.read_bytes()
        backup = manager.with_name("plug.vim.old")
        backup.mkdir()
        sentinel = backup / "existing"
        sentinel.write_bytes(b"preserve this directory")
        (self.assets / "plug.vim").write_bytes(
            original + b"\nlet g:vim_test_revision = 2\n"
        )
        result = json.loads(
            self._run_vim("""
try
  VimSetup
catch
  let g:result = v:exception
endtry
""")
        )
        self.assertIsInstance(result, str)
        self.assertIn("VimSetup:", result)
        self.assertEqual(manager.read_bytes(), original)
        self.assertEqual(sentinel.read_bytes(), b"preserve this directory")
        self.assertFalse(Path(self.env["INSTALL_LOG"]).exists())
        self.assertEqual(list(manager.parent.glob("*.download-*")), [])

    def test_backup_restores_a_manager_after_an_upstream_source_error(self) -> None:
        self._seed_manager()
        manager = self.home / ".vim/autoload/plug.vim"
        original = manager.read_bytes()
        (self.assets / "plug.vim").write_text(
            "throw 'injected upstream source failure'\n"
        )
        result = json.loads(
            self._run_vim("""
try
  VimSetup
catch
  let g:result = v:exception
endtry
""")
        )
        self.assertEqual(result, "injected upstream source failure")
        backup = manager.with_name("plug.vim.old")
        self.assertEqual(backup.read_bytes(), original)
        self.assertFalse(Path(self.env["INSTALL_LOG"]).exists())

        shutil.copyfile(backup, manager)
        result = json.loads(
            self._run_vim("""
call setline(1, ['first', 'second'])
normal n
let g:result = [line('.'), len(g:plugs)]
""")
        )
        self.assertEqual(result, [2, 27])

    def test_failed_refresh_preserves_the_installed_manager_without_installing(
        self,
    ) -> None:
        self._seed_manager()
        manager = self.home / ".vim/autoload/plug.vim"
        manager.write_text(
            manager.read_text() + "\nlet g:vim_test_manager_source = 'existing'\n"
        )
        original = manager.read_bytes()
        backup = manager.with_name("plug.vim.old")
        previous = b"let g:vim_test_revision = 0\n"
        backup.write_bytes(previous)
        for failure in ("FAIL_ASSET", "EMPTY_ASSET"):
            with self.subTest(failure=failure):
                self.env[failure] = "plug.vim"
                result = json.loads(
                    self._run_vim("""
try
  VimSetup
catch
  let g:result = [v:exception, g:vim_test_manager_source]
endtry
""")
                )
                self.assertIsInstance(result, list)
                self.assertIn("VimSetup:", result[0])
                self.assertEqual(result[1], "existing")
                self.assertEqual(manager.read_bytes(), original)
                self.assertEqual(backup.read_bytes(), previous)
                self.assertFalse(Path(self.env["INSTALL_LOG"]).exists())
                self.assertEqual(list(manager.parent.glob("*.download-*")), [])
                del self.env[failure]

    def test_failed_and_empty_downloads_are_not_published_and_can_retry(self) -> None:
        for failure in ("FAIL_ASSET", "EMPTY_ASSET"):
            with self.subTest(failure=failure):
                self.env[failure] = "plug.vim"
                result = json.loads(
                    self._run_vim("""
try
  VimSetup
catch
  let g:result = v:exception
endtry
""")
                )
                self.assertIn("VimSetup:", result)
                self.assertFalse((self.home / ".vim/autoload/plug.vim").exists())
                self.assertEqual(list((self.home / ".vim").rglob("*.download-*")), [])
                self.assertFalse(Path(self.env["INSTALL_LOG"]).exists())
                del self.env[failure]
        self._run_vim("VimSetup")
        self.assertEqual(
            Path(self.env["INSTALL_LOG"]).read_text().splitlines(), ["--sync"]
        )

    def test_partial_recovery_can_resume_after_a_color_download_failure(self) -> None:
        self.env["FAIL_ASSET"] = "wombat256.vim"
        self._run_vim("""
try
  VimSetup
catch
  let g:result = v:exception
endtry
""")
        self.assertTrue((self.home / ".vim/autoload/plug.vim").is_file())
        self.assertFalse((self.home / ".vim/colors/wombat256.vim").exists())
        self.assertFalse(Path(self.env["INSTALL_LOG"]).exists())
        del self.env["FAIL_ASSET"]
        self._run_vim("VimSetup")
        self.assertEqual(
            Path(self.env["INSTALL_LOG"]).read_text().splitlines(), ["--sync"]
        )

    def test_missing_prerequisites_refuse_setup(self) -> None:
        for tool in ("git", "curl"):
            with self.subTest(tool=tool):
                executable = self.bin / tool
                executable.rename(self.bin / (tool + ".disabled"))
                result = json.loads(
                    self._run_vim("""
try
  VimSetup
catch
  let g:result = v:exception
endtry
""")
                )
                self.assertIn("VimSetup:", result)
                self.assertFalse(Path(self.env["CURL_LOG"]).exists())
                self.assertFalse(Path(self.env["INSTALL_LOG"]).exists())
                (self.bin / (tool + ".disabled")).rename(executable)

    def test_existing_empty_asset_is_not_overwritten(self) -> None:
        color = self.home / ".vim/colors/evening_custom.vim"
        color.parent.mkdir(parents=True)
        color.touch()
        result = json.loads(
            self._run_vim("""
try
  VimSetup
catch
  let g:result = v:exception
endtry
""")
        )
        self.assertIn("VimSetup:", result)
        self.assertEqual(color.read_bytes(), b"")
        self.assertFalse(Path(self.env["INSTALL_LOG"]).exists())

    def test_plugin_installation_exception_remains_visible(self) -> None:
        self.env["FAIL_INSTALL"] = "1"
        result = json.loads(
            self._run_vim("""
try
  VimSetup
catch
  let g:result = v:exception
endtry
""")
        )
        self.assertEqual(result, "injected plugin installation failure")

    def test_recovered_colors_load_after_restarting_vim(self) -> None:
        self._run_vim("VimSetup")
        result = json.loads(
            self._run_vim("""
let g:result = []
for name in ['evening_custom', 'wombat256', 'wombat256mod']
  execute 'colorscheme ' . name
  call add(g:result, g:colors_name)
endfor
""")
        )
        self.assertEqual(result, ["evening_custom", "wombat256", "wombat256mod"])


class LatestManagerTests(VimTestCase):
    _manager_source: Path

    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        temporary = tempfile.TemporaryDirectory(prefix="latest vim-plug ")
        cls.addClassCleanup(temporary.cleanup)
        cls._manager_source = Path(temporary.name) / "plug.vim"
        with urllib.request.urlopen(LATEST_MANAGER_URL, timeout=30) as response:
            cls._manager_source.write_bytes(response.read())

    def test_latest_manager_parses_declarations_without_installing(self) -> None:
        self._seed_manager(self._manager_source)
        result = json.loads(
            self._run_vim("""
let g:result = [len(g:plugs), g:plugs.fzf.do, g:plugs.fzf.dir, g:ale_fixers.python]
enew!
setfiletype python
call add(g:result, &shiftwidth)
enew!
setfiletype text
call add(g:result, &shiftwidth)
""")
        )
        self.assertEqual(result[:2], [27, "./install --bin"])
        self.assertEqual(
            Path(result[2]).resolve(), (self.home / ".vim/plugged/fzf").resolve()
        )
        self.assertEqual(result[3], ["ruff_format", "isort"])
        self.assertEqual(result[4:], [4, 2])
        self.assertFalse(Path(self.env["CURL_LOG"]).exists())
        self.assertFalse(Path(self.env["INSTALL_LOG"]).exists())


if __name__ == "__main__":
    unittest.main()
