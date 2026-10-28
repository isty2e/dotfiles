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
PIXI_SOURCE = REPO / "home/pixi-env/base/pixi.toml"
MISE_SOURCE = REPO / "home/private_dot_config/mise/config.toml"
DAEM_SOURCE = REPO / "home/private_dot_config/daem/daem.toml"
STARSHIP_SOURCE = REPO / "home/private_dot_config/starship.toml"
SHELL_COMMON_SOURCE = REPO / "home/private_dot_config/dotfiles/shell/common.sh"
SHELL_PLUGINS_SOURCE = REPO / "home/private_dot_config/dotfiles/shell/plugins.toml"
SHELL_PLUGIN_PATHS_SOURCE = (
    REPO / "home/private_dot_config/dotfiles/shell/plugin-paths.sh"
)
SHELL_LOCAL_SOURCE = REPO / "home/private_dot_config/dotfiles/shell/local-loader.sh"
SHELL_HANDOFF_SOURCE = REPO / "home/private_dot_config/dotfiles/shell/bash-handoff.sh"
SHELL_BASH_COMPLETION_SOURCE = (
    REPO / "home/private_dot_config/dotfiles/shell/bash-completion.sh"
)
SHELL_ENVIRONMENT_SOURCE = (
    REPO / "home/private_dot_config/dotfiles/shell/environment.sh"
)
SHELL_ZSH_PLUGINS_SOURCE = (
    REPO / "home/private_dot_config/dotfiles/shell/zsh-plugins.zsh"
)
SHELL_BASH_HISTORY_SOURCE = (
    REPO / "home/private_dot_config/dotfiles/shell/bash-history.sh"
)
SHELL_ZSH_OPTIONS_SOURCE = (
    REPO / "home/private_dot_config/dotfiles/shell/zsh-options.zsh"
)
SHELL_PROMPT_SOURCE = REPO / "home/private_dot_config/dotfiles/shell/prompt.sh"
SHELL_PLATFORM_SOURCE = REPO / "home/private_dot_config/dotfiles/shell/platform.sh"
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
        self.source = REPO
        self.home = self.root / "process home"
        self.destination = self.root / "destination"
        self.former = self.root / "former source"
        for directory in (self.home, self.destination, self.former, self.root / "tmp"):
            directory.mkdir()
        self.sources = {
            Path(".vimrc"): VIM_SOURCE,
            Path("pixi-env/base/pixi.toml"): PIXI_SOURCE,
            Path(".config/mise/config.toml"): MISE_SOURCE,
            Path(".config/daem/daem.toml"): DAEM_SOURCE,
            Path(".config/starship.toml"): STARSHIP_SOURCE,
            Path(".config/dotfiles/shell/common.sh"): SHELL_COMMON_SOURCE,
            Path(".config/dotfiles/shell/plugins.toml"): SHELL_PLUGINS_SOURCE,
            Path(".config/dotfiles/shell/plugin-paths.sh"): SHELL_PLUGIN_PATHS_SOURCE,
            Path(".config/dotfiles/shell/local-loader.sh"): SHELL_LOCAL_SOURCE,
            Path(".config/dotfiles/shell/bash-handoff.sh"): SHELL_HANDOFF_SOURCE,
            Path(
                ".config/dotfiles/shell/bash-completion.sh"
            ): SHELL_BASH_COMPLETION_SOURCE,
            Path(".config/dotfiles/shell/environment.sh"): SHELL_ENVIRONMENT_SOURCE,
            Path(".config/dotfiles/shell/zsh-plugins.zsh"): SHELL_ZSH_PLUGINS_SOURCE,
            Path(".config/dotfiles/shell/bash-history.sh"): SHELL_BASH_HISTORY_SOURCE,
            Path(".config/dotfiles/shell/zsh-options.zsh"): SHELL_ZSH_OPTIONS_SOURCE,
            Path(".config/dotfiles/shell/prompt.sh"): SHELL_PROMPT_SOURCE,
            Path(".config/dotfiles/shell/platform.sh"): SHELL_PLATFORM_SOURCE,
            Path(".bashrc"): SHELL_BASHRC_SOURCE,
            Path(".zshrc"): SHELL_ZSHRC_SOURCE,
        }
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
            "PATH": str(self.home / ".local/bin") + os.pathsep + os.defpath,
            "SHELL": "/bin/sh",
            "LANG": "en_US.UTF-8",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
        }
        mise = self.home / ".local/bin/mise"
        mise.parent.mkdir(parents=True)
        mise.write_text(
            "#!/bin/sh\nset -eu\n"
            '[ -f "$MISE_GLOBAL_CONFIG_FILE" ]\n'
            'if [ "${3:-}" = which ]; then\n'
            '  printf "%s\\n" "$HOME/.local/bin/sheldon"\n'
            "  exit 0\n"
            "fi\n"
            'printf "%s\\n" "$MISE_GLOBAL_CONFIG_FILE" "$@" >> "$HOME/mise-calls"\n'
            '[ ! -f "$HOME/fail-mise" ]\n'
        )
        mise.chmod(0o755)

        sheldon = self.home / ".local/bin/sheldon"
        sheldon.write_text(
            "#!/bin/sh\nset -eu\n"
            'if [ "$5" = lock ]; then\n'
            '  printf "%s\\n" "$2" >> "$HOME/sheldon-calls"\n'
            '  mkdir -p "$4/repos/github.com/zsh-users/zsh-completions"\n'
            '  printf "%s\\n" attempt > "$4/repos/github.com/zsh-users/zsh-completions/marker"\n'
            '  [ ! -f "$HOME/fail-sheldon" ]\n'
            "  exit 0\n"
            "fi\n"
            '[ "$5" = --quiet ] && [ "$6" = source ]\n'
            'printf "%s\\n" "prepared loader"\n'
        )
        sheldon.chmod(0o755)

    def _chezmoi(self, *arguments: str) -> str:
        assert CHEZMOI is not None
        result = subprocess.run(
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
            check=False,
            timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def test_only_authored_configuration_files_are_managed(self) -> None:
        managed = self._chezmoi("managed", "--include=files", "--path-style=relative")
        expected = {path.as_posix() for path in self.sources}
        self.assertEqual(set(managed.splitlines()), expected)

    def test_shell_plugins_retry_after_failed_preparation(self) -> None:
        failure = self.home / "fail-sheldon"
        failure.touch()

        with self.assertRaises(AssertionError):
            self._chezmoi("apply")

        state = self.destination / ".local/share/dotfiles/sheldon"
        self.assertFalse((state / "current").exists())

        failure.unlink()
        self._chezmoi("apply")
        generation = (state / "current").read_text().strip()
        self.assertTrue(
            (state / "generations" / generation / "zsh-plugins.zsh").is_file()
        )

        calls = (self.home / "sheldon-calls").read_text()
        self._chezmoi("apply")
        self._chezmoi("verify")
        self.assertEqual((self.home / "sheldon-calls").read_text(), calls)

    def test_full_apply_installs_tools_after_configuration_and_skips_repeats(
        self,
    ) -> None:
        self._chezmoi("apply")
        calls = self.home / "mise-calls"
        self.assertEqual(
            calls.read_text().splitlines()[0],
            str(self.destination / ".config/mise/config.toml"),
        )
        self.assertCountEqual(
            calls.read_text().splitlines()[1:],
            ["--cd", str(self.destination), "install"],
        )
        initial = calls.read_bytes()
        self._chezmoi("apply")
        self.assertEqual(calls.read_bytes(), initial)

    def test_mise_declaration_change_runs_install_again(self) -> None:
        self.source = self.root / "source"
        self.source.mkdir()
        shutil.copyfile(REPO / ".chezmoiroot", self.source / ".chezmoiroot")
        shutil.copytree(REPO / "home", self.source / "home")
        self._chezmoi("apply")
        calls = self.home / "mise-calls"
        initial = calls.read_bytes()
        declaration = self.source / MISE_SOURCE.relative_to(REPO)
        declaration.write_text('[tools]\nnode = "22"\n')

        self._chezmoi("apply")
        self.assertEqual(calls.read_bytes(), initial * 2)
        self.assertEqual(
            (self.destination / ".config/mise/config.toml").read_bytes(),
            declaration.read_bytes(),
        )
        repeated = calls.read_bytes()
        self._chezmoi("apply")
        self.assertEqual(calls.read_bytes(), repeated)

    def test_plugin_declaration_change_preserves_previous_generation(self) -> None:
        self.source = self.root / "source"
        self.source.mkdir()
        shutil.copyfile(REPO / ".chezmoiroot", self.source / ".chezmoiroot")
        shutil.copytree(REPO / "home", self.source / "home")
        self._chezmoi("apply")

        calls = self.home / "sheldon-calls"
        initial = calls.read_text()
        state = self.destination / ".local/share/dotfiles/sheldon"
        old_generation = (state / "current").read_text().strip()
        old_loader = state / "generations" / old_generation / "zsh-plugins.zsh"
        old_content = old_loader.read_bytes()
        declaration = self.source / SHELL_PLUGINS_SOURCE.relative_to(REPO)
        with declaration.open("a") as output:
            output.write('\n[plugins.example]\ngithub = "example/example"\n')

        self._chezmoi("apply")
        self.assertEqual(calls.read_text(), initial * 2)
        new_generation = (state / "current").read_text().strip()
        self.assertNotEqual(new_generation, old_generation)
        self.assertEqual(old_loader.read_bytes(), old_content)
        self.assertTrue(
            (state / "generations" / new_generation / "zsh-plugins.zsh").is_file()
        )

    def test_failed_repreparation_keeps_active_generation(self) -> None:
        self.source = self.root / "source"
        self.source.mkdir()
        shutil.copyfile(REPO / ".chezmoiroot", self.source / ".chezmoiroot")
        shutil.copytree(REPO / "home", self.source / "home")
        self._chezmoi("apply")

        state = self.destination / ".local/share/dotfiles/sheldon"
        pointer = state / "current"
        active = pointer.read_text().strip()
        marker = (
            state
            / "generations"
            / active
            / "repos/github.com/zsh-users/zsh-completions/marker"
        )
        marker.write_text("preserved checkout")
        declaration = self.source / SHELL_PLUGINS_SOURCE.relative_to(REPO)
        with declaration.open("a") as output:
            output.write('\n[plugins.example]\ngithub = "example/example"\n')

        failure = self.home / "fail-sheldon"
        failure.touch()
        with self.assertRaises(AssertionError):
            self._chezmoi("apply")

        self.assertEqual(pointer.read_text().strip(), active)
        self.assertEqual(marker.read_text(), "preserved checkout")

        failure.unlink()
        self._chezmoi("apply")
        self.assertNotEqual(pointer.read_text().strip(), active)
        self.assertEqual(marker.read_text(), "preserved checkout")

    def test_migration_preserves_legacy_plugin_checkout(self) -> None:
        self.source = self.root / "source"
        self.source.mkdir()
        shutil.copyfile(REPO / ".chezmoiroot", self.source / ".chezmoiroot")
        shutil.copytree(REPO / "home", self.source / "home")
        shell_source = self.source / "home/private_dot_config/dotfiles/shell"
        (shell_source / "plugins.toml").unlink()
        (shell_source / "plugin-paths.sh").unlink()
        (shell_source / "plugins.list").write_text("legacy example.invalid/legacy\n")
        action = self.source / "home/run_onchange_after_install-shell-plugins.sh.tmpl"
        action.write_text(
            "#!/bin/sh\nset -eu\n"
            'mkdir -p "$CHEZMOI_DEST_DIR/.local/share/dotfiles/plugins/legacy"\n'
            'printf "%s\\n" "legacy checkout" > '
            '"$CHEZMOI_DEST_DIR/.local/share/dotfiles/plugins/legacy/marker"\n'
        )
        self._chezmoi("apply")

        legacy = self.destination / ".local/share/dotfiles/plugins/legacy/marker"
        self.assertEqual(legacy.read_text(), "legacy checkout\n")
        (shell_source / "plugins.list").unlink()
        shutil.copyfile(SHELL_PLUGINS_SOURCE, shell_source / "plugins.toml")
        shutil.copyfile(SHELL_PLUGIN_PATHS_SOURCE, shell_source / "plugin-paths.sh")
        shutil.copyfile(REPO / action.relative_to(self.source), action)

        self._chezmoi("apply")
        self.assertEqual(legacy.read_text(), "legacy checkout\n")
        self.assertTrue(
            (self.destination / ".local/share/dotfiles/sheldon/current").is_file()
        )

    def test_failed_install_is_retried_without_rolling_back_configuration(self) -> None:
        failure = self.home / "fail-mise"
        failure.touch()
        with self.assertRaises(AssertionError):
            self._chezmoi("apply")
        self.assertEqual(
            (self.destination / ".config/mise/config.toml").read_bytes(),
            MISE_SOURCE.read_bytes(),
        )
        calls = self.home / "mise-calls"
        initial = calls.read_bytes()
        failure.unlink()

        self._chezmoi("apply")
        self.assertEqual(calls.read_bytes(), initial * 2)
        recovered = calls.read_bytes()
        self._chezmoi("apply")
        self.assertEqual(calls.read_bytes(), recovered)

    def test_placement_only_apply_defers_installation_until_full_apply(self) -> None:
        self._chezmoi("apply", "--exclude=scripts")
        self.assertFalse((self.home / "mise-calls").exists())
        self.assertFalse((self.home / "sheldon-calls").exists())
        self.assertEqual(
            (self.destination / ".config/mise/config.toml").read_bytes(),
            MISE_SOURCE.read_bytes(),
        )
        self._chezmoi("apply")
        self.assertTrue((self.home / "mise-calls").is_file())

    def test_pixi_generated_state_is_not_deployed(self) -> None:
        self.source = self.root / "source"
        self.source.mkdir()
        (self.source / ".chezmoiroot").write_bytes((REPO / ".chezmoiroot").read_bytes())
        shutil.copytree(REPO / "home", self.source / "home")
        workspace = Path("pixi-env/base")
        prefix = workspace / ".pixi/envs/default/bin/python"
        generated = self.source / "home" / prefix
        generated.parent.mkdir(parents=True)
        generated.write_bytes(b"generated source environment")
        (self.source / "home" / workspace / "pixi.lock").write_bytes(
            b"generated source solver state"
        )

        existing = self.destination / prefix
        existing.parent.mkdir(parents=True)
        existing.write_bytes(b"existing installed environment")
        local_state = self.destination / workspace / "pixi.lock"
        local_state.write_bytes(b"local solver state")

        managed = self._chezmoi("managed", "--include=files", "--path-style=relative")
        self.assertEqual(
            set(managed.splitlines()), {p.as_posix() for p in self.sources}
        )
        for _ in range(2):
            self._chezmoi("apply")
            self._chezmoi("verify")
            self.assertEqual(
                (self.destination / workspace / "pixi.toml").read_bytes(),
                PIXI_SOURCE.read_bytes(),
            )
            self.assertEqual(existing.read_bytes(), b"existing installed environment")
            self.assertEqual(local_state.read_bytes(), b"local solver state")

    def test_daem_generated_state_is_not_deployed_or_captured(self) -> None:
        self.source = self.root / "source"
        self.source.mkdir()
        shutil.copyfile(REPO / ".chezmoiroot", self.source / ".chezmoiroot")
        shutil.copytree(REPO / "home", self.source / "home")

        workspace = Path(".config/daem")
        declaration = self.source / "home/private_dot_config/daem/daem.toml"
        self.sources[workspace / "daem.toml"] = declaration
        artifacts = {
            Path("daem.lock.toml"): (Path("daem.lock.toml"), b"source lock"),
            Path("dot_daem/state.json"): (Path(".daem/state.json"), b"source state"),
            Path("dot_daem/cache/entry"): (Path(".daem/cache/entry"), b"source cache"),
        }
        for source_path, (target_path, content) in artifacts.items():
            source = declaration.parent / source_path
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_bytes(content)
            destination = self.destination / workspace / target_path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(b"local " + content)

        source_only = Path("dot_daem/cache/source-only")
        (declaration.parent / source_only).write_bytes(b"source-only artifact")
        managed = self._chezmoi("managed", "--include=files", "--path-style=relative")
        self.assertEqual(
            set(managed.splitlines()), {path.as_posix() for path in self.sources}
        )

        for _ in range(2):
            self._chezmoi("apply", "--exclude=scripts")
            self._chezmoi("verify", "--exclude=scripts")
            self.assertEqual(
                (self.destination / workspace / "daem.toml").read_bytes(),
                declaration.read_bytes(),
            )
            for target_path, content in artifacts.values():
                self.assertEqual(
                    (self.destination / workspace / target_path).read_bytes(),
                    b"local " + content,
                )
            self.assertFalse(
                (self.destination / workspace / ".daem/cache/source-only").exists()
            )

        before_edit = declaration.read_bytes()
        edited = b'version = 1\ntargets = ["claude-code"]\n'
        (self.destination / workspace / "daem.toml").write_bytes(edited)
        self.assertEqual(declaration.read_bytes(), before_edit)
        for target_path, _ in artifacts.values():
            (self.destination / workspace / target_path).write_bytes(
                b"changed local state"
            )
        self._chezmoi("re-add")

        self.assertEqual(declaration.read_bytes(), edited)
        for source_path, (_, content) in artifacts.items():
            self.assertEqual((declaration.parent / source_path).read_bytes(), content)
        self.assertEqual(
            (declaration.parent / source_only).read_bytes(), b"source-only artifact"
        )
        self._chezmoi("apply", "--exclude=scripts")
        self._chezmoi("verify", "--exclude=scripts")
        for target_path, _ in artifacts.values():
            self.assertEqual(
                (self.destination / workspace / target_path).read_bytes(),
                b"changed local state",
            )

    @unittest.skipUnless(GIT, "Git is required")
    def test_git_excludes_daem_generated_state_but_tracks_manifest(self) -> None:
        assert GIT is not None
        repository = self.root / "git checkout"
        repository.mkdir()
        shutil.copyfile(REPO / ".gitignore", repository / ".gitignore")
        workspace = Path("home/private_dot_config/daem")
        for path in (
            Path("daem.toml"),
            Path("daem.lock.toml"),
            Path(".daem/state.json"),
            Path(".daem/cache/entry"),
        ):
            generated = repository / workspace / path
            generated.parent.mkdir(parents=True, exist_ok=True)
            generated.write_bytes(b"fixture")

        for arguments in (("init", "--quiet"), ("add", "--all")):
            subprocess.run(
                [GIT, *arguments],
                cwd=repository,
                env=self.environment,
                capture_output=True,
                text=True,
                check=True,
                timeout=30,
            )
        tracked = subprocess.run(
            [GIT, "ls-files"],
            cwd=repository,
            env=self.environment,
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        )
        self.assertEqual(
            set(tracked.stdout.splitlines()),
            {".gitignore", (workspace / "daem.toml").as_posix()},
        )

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
