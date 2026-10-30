import os
import shlex
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

import tomllib

REPO = Path(__file__).resolve().parents[2]
VIM_SOURCE = REPO / "home/dot_vimrc"
NVIM_SOURCE = REPO / "home/private_dot_config/nvim"
HELIX_SOURCE = REPO / "home/private_dot_config/helix"
ZED_SOURCE = REPO / "home/private_dot_config/zed"
SLURM_SOURCE = REPO / "home/dot_local/bin"
SHELL_BASHRC_SOURCE = REPO / "home/dot_bashrc"
SHELL_ZSHRC_SOURCE = REPO / "home/dot_zshrc"
_configured_chezmoi = os.environ.get("CHEZMOI")
_selected_chezmoi = (
    shutil.which(_configured_chezmoi or "chezmoi") or _configured_chezmoi
)
CHEZMOI = (
    str(Path(_selected_chezmoi).expanduser().resolve()) if _selected_chezmoi else None
)
GIT = shutil.which("git")
DAEM = shutil.which(os.environ.get("DAEM", "daem"))
ZSH = shutil.which("zsh")
BUN = shutil.which(os.environ.get("BUN", "bun"))


@unittest.skipUnless(CHEZMOI, "chezmoi is required; set CHEZMOI to its executable")
class ChezmoiSourceTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="chezmoi source '$ ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.source = self.root / "checkout '$"
        self.source.mkdir()
        shutil.copyfile(REPO / ".chezmoiroot", self.source / ".chezmoiroot")
        shutil.copytree(
            REPO / "home",
            self.source / "home",
            ignore=shutil.ignore_patterns("__pycache__"),
        )
        hook = self.root / "summary-preload.js"
        hook.write_text("// Offline external-file fixture.\n")
        feature = (
            self.source / "home/.chezmoitemplates/claude-no-agent-summary/manifest.toml"
        )
        enabled = tomllib.loads(feature.read_text())["enabled"]
        feature.write_text(
            f'enabled = {str(enabled).lower()}\nurl = "{hook.as_uri()}"\n'
        )
        for workspace, name in (
            ("mise", "config.toml"),
            ("daem", "daem.toml"),
            ("pixi-base", "pixi.toml"),
            ("sheldon", "plugins.toml"),
        ):
            target = self.source / "workspaces" / workspace / name
            target.parent.mkdir(parents=True)
            shutil.copyfile(REPO / "workspaces" / workspace / name, target)
        self.home = self.root / "process home"
        self.destination = self.root / "destination"
        self.former = self.root / "former source"
        for directory in (self.home, self.destination, self.former, self.root / "tmp"):
            directory.mkdir()
        self.environment = {
            "HOME": str(self.home),
            "PATH": os.defpath,
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "XDG_CACHE_HOME": str(self.home / ".cache"),
            "XDG_STATE_HOME": str(self.home / ".local/state"),
            "TMPDIR": str(self.root / "tmp"),
            "SHELL": "/bin/sh",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
        }
        self.sources = {}
        for name, source in (
            ("nvim", NVIM_SOURCE),
            ("helix", HELIX_SOURCE),
            ("zed", ZED_SOURCE),
        ):
            self.sources.update(
                (Path(".config") / name / p.relative_to(source), p)
                for p in source.rglob("*")
                if p.is_file()
            )

    def _summary_options(self, options: str = "") -> list[str]:
        assert ZSH is not None
        result = subprocess.run(
            [
                ZSH,
                "-f",
                "-c",
                (
                    '. "$HOME/.zshenv"; . "$HOME/.zshenv"; '
                    'for option in "${(@z)${BUN_OPTIONS-}}"; do '
                    'if [[ -n $option ]]; then print -r -- "${(Q)option}"; fi; done'
                ),
            ],
            env=self.environment
            | {"HOME": str(self.destination), "BUN_OPTIONS": options},
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
        return result.stdout.splitlines()

    def _run(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        assert CHEZMOI is not None
        return subprocess.run(
            [
                CHEZMOI,
                "--source",
                str(self.source),
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
            timeout=30,
            check=False,
        )

    def _chezmoi(self, *arguments: str) -> str:
        result = self._run(*arguments)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def test_apply_only_places_settings_and_native_bindings(self) -> None:
        self._chezmoi("apply")
        for name in ("mise", "daem"):
            path = self.destination / ".config" / name
            self.assertTrue(path.is_symlink())
            self.assertEqual(path.resolve(), self.source / "workspaces" / name)
        self.assertEqual(
            (self.destination / ".bashrc").read_bytes(),
            SHELL_BASHRC_SOURCE.read_bytes(),
        )
        self.assertEqual(
            (self.destination / ".config/helix/config.toml").read_bytes(),
            (HELIX_SOURCE / "config.toml").read_bytes(),
        )
        self.assertEqual(
            stat.S_IMODE((self.destination / ".config").stat().st_mode), 0o700
        )
        self.assertEqual(
            stat.S_IMODE((self.destination / ".config/shell").stat().st_mode), 0o700
        )
        self.assertEqual(
            stat.S_IMODE((self.destination / ".config/daem").stat().st_mode), 0o700
        )
        self.assertEqual(
            stat.S_IMODE((self.destination / ".config/daem/daem.toml").stat().st_mode),
            0o600,
        )
        self.assertFalse((self.home / ".local/share/mise").exists())
        self.assertFalse((self.home / ".local/share/dotfiles/sheldon").exists())
        self.assertFalse((self.source / "workspaces/pixi-base/.pixi").exists())
        self._chezmoi("apply")
        self._chezmoi("verify")

    def test_source_change_is_deployed_without_installation(self) -> None:
        self._chezmoi("apply")
        source = self.source / "home/private_dot_config/starship.toml"
        source.write_text("add_newline = false\n")
        self._chezmoi("apply")
        self.assertEqual(
            (self.destination / ".config/starship.toml").read_bytes(),
            source.read_bytes(),
        )

    def test_atomic_native_save_updates_source_and_preserves_directory_link(
        self,
    ) -> None:
        self._chezmoi("apply")
        for name, filename in (("mise", "config.toml"), ("daem", "daem.toml")):
            directory = self.destination / ".config" / name
            temporary = directory / "replacement"
            temporary.write_text("# native saved declaration\n")
            temporary.replace(directory / filename)
            self.assertTrue(directory.is_symlink())
            self.assertEqual(
                (self.source / "workspaces" / name / filename).read_text(),
                "# native saved declaration\n",
            )
        self._chezmoi("apply")
        self.assertEqual(
            (self.destination / ".config/daem/daem.toml").read_text(),
            "# native saved declaration\n",
        )

    def test_existing_native_directory_and_state_are_not_auto_adopted(self) -> None:
        directory = self.destination / ".config/daem"
        directory.mkdir(parents=True)
        directory.parent.chmod(0o700)
        directory.chmod(0o700)
        (directory / "daem.toml").write_text("# existing local manifest\n")
        state = directory / ".daem/state.json"
        state.parent.mkdir()
        state.write_text("existing ownership\n")
        result = self._run("apply", "--less-interactive", "--error-on-conflict")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(directory.is_symlink())
        self.assertEqual(state.read_text(), "existing ownership\n")
        self.assertEqual(
            (directory / "daem.toml").read_text(), "# existing local manifest\n"
        )

    @unittest.skipUnless(DAEM, "native daem CLI is optional")
    def test_native_daem_authoring_and_apply_use_the_bound_workspace(self) -> None:
        assert DAEM is not None
        self._chezmoi("apply")
        manifest = self.source / "workspaces/daem/daem.toml"
        manifest.write_text(
            'version = 1\ntargets = ["pi"]\n[defaults]\nscope = "global"\n'
        )
        fixture = self.root / "instruction.md"
        fixture.write_text("Synthetic native authoring fixture.\n")
        environment = self.environment | {
            "HOME": str(self.destination),
            "XDG_CONFIG_HOME": str(self.destination / ".config"),
        }
        for arguments in (
            ("add", "instruction", "fixture", str(fixture), "--json"),
            ("apply", "--dry-run", "--json"),
            ("apply", "--yes", "--json"),
        ):
            result = subprocess.run(
                [DAEM, *arguments],
                env=environment,
                cwd=self.root,
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.destination / ".config/daem").is_symlink())
        self.assertTrue((manifest.parent / "daem.lock.toml").is_file())
        self.assertEqual(
            (self.destination / ".pi/agent/AGENTS.md").read_bytes(),
            fixture.read_bytes(),
        )
        self._chezmoi("apply")
        self.assertEqual(
            (self.destination / ".pi/agent/AGENTS.md").read_bytes(),
            fixture.read_bytes(),
        )

    def test_live_edit_and_unmanaged_files_survive_conflicting_apply(self) -> None:
        self._chezmoi("apply")
        target = self.destination / ".zshrc"
        target.write_text("local edit\n")
        source = self.source / "home/dot_zshrc"
        source.write_text("new source\n")
        result = self._run("apply", "--less-interactive", "--error-on-conflict")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(target.read_text(), "local edit\n")
        self.assertEqual(source.read_text(), "new source\n")

    def test_retired_source_state_requires_preservation_before_binding(self) -> None:
        retired = self.source / "home/private_dot_config/private_daem"
        state = retired / ".daem/state.json"
        state.parent.mkdir(parents=True)
        state.write_bytes(b"previous native ownership")
        result = self._run("apply", "--less-interactive", "--error-on-conflict")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(state.read_bytes(), b"previous native ownership")
        state.parent.rename(self.source / "workspaces/daem/.daem")
        retired.rmdir()
        self._chezmoi("apply")
        self.assertEqual(
            (self.destination / ".config/daem/.daem/state.json").read_bytes(),
            b"previous native ownership",
        )

    def test_generated_locks_state_and_existing_environments_remain_local(self) -> None:
        self._chezmoi("apply")
        fixtures = (
            self.destination / ".config/nvim/lazy-lock.json",
            self.destination / ".config/daem/daem.lock.toml",
            self.destination / ".config/daem/.daem/state.json",
            self.destination / ".config/daem/.daem/cache/entry",
            self.source / "workspaces/pixi-base/pixi.lock",
            self.source / "workspaces/pixi-base/.pixi/envs/default/bin/python",
            self.destination / "pixi-env/base/.pixi/envs/default/bin/python",
            self.destination / ".config/shell/local.sh",
            self.destination / ".config/shell/device/local.sh",
            self.destination / ".config/shell/device/credentials.sh",
        )
        for path in fixtures:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"existing local state")
        for _ in range(2):
            self._chezmoi("apply")
            self._chezmoi("verify")
            for path in fixtures:
                self.assertEqual(path.read_bytes(), b"existing local state")
        self.assertEqual(self._chezmoi("diff").strip(), "")

    def test_slurm_commands_are_placed_as_executables(self) -> None:
        self._chezmoi("apply")
        for command in ("sbatchall", "slurm-cancel"):
            target = self.destination / ".local/bin" / command
            self.assertTrue(target.stat().st_mode & stat.S_IXUSR)
            self.assertEqual(
                target.read_bytes(),
                (SLURM_SOURCE / ("executable_" + command)).read_bytes(),
            )

    def test_rendered_shell_path_uses_the_actual_checkout(self) -> None:
        self._chezmoi("apply")
        fragment = self.destination / ".config/shell/workspaces.sh"
        result = subprocess.run(
            [
                "/bin/sh",
                "-c",
                '. "$1"; printf "%s" "$_dotfiles_repository_manifest"',
                "fixture",
                str(fragment),
            ],
            env=self.environment,
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertEqual(
            result.stdout, str(self.source / "workspaces/pixi-base/pixi.toml")
        )

    @unittest.skipUnless(GIT, "Git is required")
    def test_git_tracks_declarations_not_locks_or_artifacts(self) -> None:
        assert GIT is not None
        shutil.copyfile(REPO / ".gitignore", self.source / ".gitignore")
        fixtures = (
            "workspaces/pixi-base/pixi.lock",
            "workspaces/pixi-base/.pixi/envs/default/bin/python",
            "workspaces/daem/daem.lock.toml",
            "workspaces/daem/.daem/state.json",
            "home/private_dot_config/nvim/lazy-lock.json",
            "home/private_dot_config/private_shell/device/local.sh",
            "home/private_dot_config/private_shell/device/credentials.sh",
        )
        for relative in fixtures:
            path = self.source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"generated fixture")
        for arguments in (("init", "-q"), ("add", "--all")):
            subprocess.run(
                [GIT, *arguments],
                cwd=self.source,
                env=self.environment,
                capture_output=True,
                check=True,
            )
        tracked = subprocess.check_output(
            [GIT, "ls-files"], cwd=self.source, env=self.environment, text=True
        ).splitlines()
        for path in fixtures:
            self.assertNotIn(path, tracked)
        self.assertIn("workspaces/daem/daem.toml", tracked)
        self.assertIn("workspaces/pixi-base/pixi.toml", tracked)

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

    @unittest.skipUnless(ZSH, "zsh is required for preload environment checks")
    def test_summary_preload_preserves_other_options_and_is_idempotent(self) -> None:
        self._chezmoi("apply", "--less-interactive", "--error-on-conflict")
        hook = self.destination / ".local/share/no-agent-summary.js"
        self.assertEqual(
            hook.read_bytes(), (self.root / "summary-preload.js").read_bytes()
        )
        preload = f"--preload={hook}"
        preload_arg = shlex.quote(preload)
        self.assertEqual(self._summary_options(), [preload])
        self.assertEqual(
            self._summary_options(
                f"--smol --preload='/other path.js' {preload_arg} {preload_arg}"
            ),
            ["--smol", "--preload=/other path.js", preload],
        )

        hook_arg = shlex.quote(str(hook))
        self.assertEqual(
            self._summary_options(f"--smol --preload {hook_arg} {preload_arg}"),
            ["--smol", preload],
        )

        saved = self.root / "saved-hook.js"
        hook.rename(saved)
        self.assertEqual(self._summary_options(f"{preload_arg} --smol"), ["--smol"])
        saved.rename(hook)
        self._chezmoi("apply", "--less-interactive", "--error-on-conflict")
        self._chezmoi("verify")

    @unittest.skipUnless(ZSH, "zsh is required for preload environment checks")
    def test_summary_preload_can_be_removed_and_reenabled(self) -> None:
        self._chezmoi("apply", "--less-interactive", "--error-on-conflict")
        hook = self.destination / ".local/share/no-agent-summary.js"
        preload = f"--preload={hook}"
        preload_arg = shlex.quote(preload)
        feature = (
            self.source / "home/.chezmoitemplates/claude-no-agent-summary/manifest.toml"
        )
        feature.write_text('enabled = false\nurl = "file:///nonexistent/disabled.js"\n')

        self._chezmoi("apply", "--less-interactive", "--error-on-conflict")
        self.assertFalse(hook.exists())
        self.assertEqual(
            self._summary_options(f"--smol {preload_arg} {preload_arg}"), ["--smol"]
        )
        self.assertEqual(self._summary_options(preload_arg), [])
        self.assertEqual(
            self._summary_options(
                f"--preload {shlex.quote(str(hook))} --smol {preload_arg}"
            ),
            ["--smol"],
        )
        self._chezmoi("apply", "--less-interactive", "--error-on-conflict")
        self._chezmoi("verify")

        fixture = self.root / "summary-preload.js"
        feature.write_text(f'enabled = true\nurl = "{fixture.as_uri()}"\n')
        self._chezmoi("apply", "--less-interactive", "--error-on-conflict")
        self.assertEqual(hook.read_bytes(), fixture.read_bytes())
        self.assertEqual(self._summary_options(), [preload])
        self._chezmoi("verify")

    @unittest.skipUnless(BUN and ZSH, "native bun and zsh are required")
    def test_summary_preload_quoting_is_accepted_by_bun(self) -> None:
        assert BUN is not None and ZSH is not None
        bun = Path(BUN).resolve()
        if bun.name == "mise":
            self.skipTest("bun resolves to a mise shim rather than a native binary")
        fixture = self.root / "summary-preload.js"
        fixture.write_text("globalThis.summaryFixture = true;\n")
        self._chezmoi("apply", "--less-interactive", "--error-on-conflict")
        result = subprocess.run(
            [
                ZSH,
                "-f",
                "-c",
                """. "$HOME/.zshenv"; exec "$BUN" --eval 'console.log(globalThis.summaryFixture)'""",
            ],
            env=self.environment
            | {
                "HOME": str(self.destination),
                "BUN": str(bun),
                "MISE_AUTO_INSTALL": "false",
                "MISE_NOT_FOUND_AUTO_INSTALL": "false",
            },
            capture_output=True,
            text=True,
            timeout=30,
            check=True,
        )
        self.assertEqual(result.stdout.strip(), "true")

    def test_summary_preload_conflict_does_not_relax_private_parent(self) -> None:
        parent = self.destination / ".local/share"
        parent.mkdir(parents=True, mode=0o700)
        parent.chmod(0o700)
        self._chezmoi("managed")
        result = self._run("apply", "--less-interactive", "--error-on-conflict")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(stat.S_IMODE(parent.stat().st_mode), 0o700)
        self.assertFalse((parent / "no-agent-summary.js").exists())


if __name__ == "__main__":
    unittest.main()
