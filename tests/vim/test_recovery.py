import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().parent / "fixtures"
VIM = shutil.which("vim")


@unittest.skipUnless(VIM, "Vim is required for the configuration integration tests")
class VimRecoveryTests(unittest.TestCase):
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
        completed = subprocess.run(
            [VIM, "-Nu", str(self.vimrc), "-n", "-i", "NONE", "-es", "-S", str(probe)],
            env=self.env,
            cwd=self.root,
            capture_output=True,
            check=False,
            text=True,
            timeout=30,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        return Path(self.env["RESULT"]).read_text()

    def _seed_manager(self, source: Path = FIXTURES / "plug.vim") -> None:
        target = self.home / ".vim/autoload/plug.vim"
        target.parent.mkdir(parents=True)
        shutil.copyfile(source, target)

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

    def test_filetype_indentation_does_not_leak_to_other_buffers(self) -> None:
        self._seed_manager(REPO / ".vim/autoload/plug.vim")
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
        self.assertEqual(len(downloads), 4)
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
        for name in (".zshrc", ".bashrc"):
            self.assertEqual(
                (self.home / name).read_text(), "keep existing shell settings\n"
            )

    def test_existing_assets_and_plugin_tree_are_preserved(self) -> None:
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
        self.assertEqual(len(Path(self.env["CURL_LOG"]).read_text().splitlines()), 2)

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

    def test_real_bundled_manager_parses_declarations_without_installing(self) -> None:
        self._seed_manager(REPO / ".vim/autoload/plug.vim")
        result = json.loads(
            self._run_vim("""
let g:result = [len(g:plugs), g:plugs.fzf.do, g:plugs.fzf.dir, g:ale_fixers.python]
""")
        )
        self.assertEqual(result[:2], [27, "./install --bin"])
        self.assertEqual(
            Path(result[2]).resolve(), (self.home / ".vim/plugged/fzf").resolve()
        )
        self.assertEqual(result[3], ["ruff_format", "isort"])
        self.assertFalse(Path(self.env["CURL_LOG"]).exists())
        self.assertFalse(Path(self.env["INSTALL_LOG"]).exists())


if __name__ == "__main__":
    unittest.main()
