import json
import os
import shlex
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
_selected_mise = shutil.which(os.environ.get("MISE", "mise"))
MISE = str(Path(_selected_mise).resolve()) if _selected_mise else None
GIT = shutil.which("git")
ZSH = shutil.which("zsh")
BUN = shutil.which(os.environ.get("BUN", "bun"))
DAEM = shutil.which(os.environ.get("DAEM", "daem"))
GHOSTTY = shutil.which(os.environ.get("GHOSTTY", "ghostty"))


@unittest.skipUnless(MISE and GIT, "native mise and Git are required")
class MiseDeploymentTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="mise source '$ ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.source = self.root / "checkout '$"
        self.source.mkdir()
        for directory in ("config", "features", "workspaces", "scripts"):
            shutil.copytree(
                REPO / directory,
                self.source / directory,
                ignore=shutil.ignore_patterns("__pycache__"),
            )
        for name in ("mise.toml", ".gitignore"):
            shutil.copyfile(REPO / name, self.source / name)
        self.hook = self.root / "summary-preload.js"
        self.hook.write_text("// Offline external-file fixture.\n")
        (self.source / "mise.local.toml").write_text(
            f"[vars]\nclaude_no_agent_summary_url = {json.dumps(self.hook.as_uri())}\n"
        )
        self.home = self.root / "home '$"
        self.home.mkdir()
        self.environment = {
            "HOME": str(self.home),
            "PATH": os.defpath,
            "SHELL": "/bin/sh",
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_CACHE_HOME": str(self.home / ".cache"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "XDG_STATE_HOME": str(self.home / ".local/state"),
            "MISE_CONFIG_DIR": str(self.home / ".config/mise"),
            "MISE_GLOBAL_CONFIG_FILE": str(self.home / ".config/mise/config.toml"),
            "MISE_DATA_DIR": str(self.home / ".local/share/mise"),
            "MISE_CACHE_DIR": str(self.home / ".cache/mise"),
            "MISE_STATE_DIR": str(self.home / ".local/state/mise"),
            "MISE_TRUSTED_CONFIG_PATHS": str(self.root),
            "MISE_AUTO_INSTALL": "false",
            "MISE_NOT_FOUND_AUTO_INSTALL": "false",
            "MISE_OFFLINE": "true",
            "MISE_YES": "1",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
        }
        assert GIT is not None
        for arguments in (("init", "-q"), ("add", "--all")):
            subprocess.run(
                [GIT, *arguments],
                cwd=self.source,
                env=self.environment,
                capture_output=True,
                check=True,
            )

    def _feature(self, enabled: bool, url: str) -> None:
        (self.source / "mise.local.toml").write_text(
            "[vars]\n"
            f"claude_no_agent_summary = {json.dumps('on' if enabled else 'off')}\n"
            f"claude_no_agent_summary_url = {json.dumps(url)}\n"
        )

    def _run(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        assert MISE is not None
        return subprocess.run(
            [MISE, *arguments],
            cwd=self.source,
            env=self.environment,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )

    def _mise(self, *arguments: str) -> str:
        result = self._run(*arguments)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

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
            env=self.environment | {"BUN_OPTIONS": options},
            capture_output=True,
            text=True,
            timeout=30,
            check=True,
        )
        return result.stdout.splitlines()

    def test_apply_only_links_configuration_and_acquires_the_declared_asset(
        self,
    ) -> None:
        self._mise("dot", "apply")
        for name in ("mise", "daem"):
            target = self.home / ".config" / name
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), self.source / "workspaces" / name)
        for target, source in (
            (".bashrc", "config/shell/bashrc"),
            (".zshrc", "config/shell/zshrc"),
            (".vimrc", "config/vim/vimrc"),
            (".config/nvim/init.lua", "config/nvim/init.lua"),
            (".config/helix/config.toml", "config/helix/config.toml"),
            (".config/zed/keymap.json", "config/zed/keymap.json"),
            (".config/ghostty/config", "config/ghostty/config"),
        ):
            deployed = self.home / target
            self.assertTrue(deployed.is_symlink())
            self.assertEqual(deployed.read_bytes(), (self.source / source).read_bytes())
        self.assertEqual(
            (self.home / ".local/share/no-agent-summary.js").read_bytes(),
            self.hook.read_bytes(),
        )
        for path in (
            self.home / ".local/share/mise/installs",
            self.home / ".local/share/dotfiles/sheldon",
            self.source / "workspaces/pixi-base/.pixi",
            self.home / ".vim",
        ):
            self.assertFalse(path.exists())
        self._mise("dot", "apply")

    def test_editing_source_or_live_link_needs_no_sync(self) -> None:
        self._mise("dot", "apply")
        source = self.source / "config/starship/starship.toml"
        target = self.home / ".config/starship.toml"
        source.write_text("add_newline = false\n")
        self.assertEqual(target.read_bytes(), source.read_bytes())
        target.write_text("add_newline = true\n")
        self.assertEqual(source.read_text(), "add_newline = true\n")

    def test_preserves_parent_modes_private_files_and_unmanaged_runtime(self) -> None:
        config = self.home / ".config"
        config.mkdir(mode=0o701)
        shell = config / "shell"
        shell.mkdir(mode=0o701)
        fixtures = (
            shell / "device/local.sh",
            shell / "device/credentials.sh",
            config / "nvim/lazy-lock.json",
            config / "helix/runtime/grammars/python.so",
            config / "zed/native-state",
            config / "ghostty/themes/local-preview",
            self.home / ".vim/installed-plugin",
            self.source / "workspaces/daem/.daem/state.json",
            self.source / "workspaces/daem/daem.lock.toml",
            self.source / "workspaces/pixi-base/.pixi/envs/default/bin/python",
            self.source / "workspaces/pixi-base/pixi.lock",
        )
        for path in fixtures:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"existing local fixture")
        for _ in range(2):
            self._mise("dot", "apply")
            for path in fixtures:
                self.assertEqual(path.read_bytes(), b"existing local fixture")
        self.assertEqual(stat.S_IMODE(config.stat().st_mode), 0o701)
        self.assertEqual(stat.S_IMODE(shell.stat().st_mode), 0o701)
        self.assertEqual(stat.S_IMODE((config / "daem").stat().st_mode), 0o700)
        self.assertEqual(
            stat.S_IMODE((config / "daem/daem.toml").stat().st_mode), 0o600
        )

    def test_an_atomic_application_save_conflicts_instead_of_overwriting(self) -> None:
        self._mise("dot", "apply")
        target = self.home / ".zshrc"
        replacement = self.home / "saved-zshrc"
        replacement.write_text("local edit\n")
        replacement.replace(target)
        source = self.source / "config/shell/zshrc"
        source.write_text("new source\n")
        self.assertNotEqual(self._run("dot", "apply").returncode, 0)
        self.assertEqual(target.read_text(), "local edit\n")
        self.assertEqual(source.read_text(), "new source\n")

    def test_existing_native_workspace_is_not_force_adopted(self) -> None:
        directory = self.home / ".config/daem"
        directory.mkdir(parents=True)
        manifest = directory / "daem.toml"
        manifest.write_text("# local declaration\n")
        state = directory / ".daem/state.json"
        state.parent.mkdir()
        state.write_text("existing ownership\n")
        self.assertNotEqual(self._run("dot", "apply").returncode, 0)
        self.assertFalse(directory.is_symlink())
        self.assertEqual(manifest.read_text(), "# local declaration\n")
        self.assertEqual(state.read_text(), "existing ownership\n")

    def test_atomic_native_save_preserves_workspace_directory_links(self) -> None:
        self._mise("dot", "apply")
        for name, filename in (("mise", "config.toml"), ("daem", "daem.toml")):
            target = self.home / ".config" / name
            temporary = target / "replacement"
            temporary.write_text("# native saved declaration\n")
            temporary.replace(target / filename)
            self.assertTrue(target.is_symlink())
            self.assertEqual(
                (self.source / "workspaces" / name / filename).read_text(),
                "# native saved declaration\n",
            )
        self._mise("dot", "apply")

    def test_source_only_generated_files_are_not_deployed(self) -> None:
        generated = self.source / "config/ghostty/themes/generated-preview"
        generated.write_text("background = 010203\n")
        self._mise("dot", "apply")
        self.assertFalse(
            (self.home / ".config/ghostty/themes/generated-preview").exists()
        )
        assert GIT is not None
        subprocess.run([GIT, "add", str(generated)], cwd=self.source, check=True)
        self._mise("dot", "apply")
        self.assertEqual(
            (self.home / ".config/ghostty/themes/generated-preview").read_bytes(),
            generated.read_bytes(),
        )

    def test_prune_removes_deselected_group_links_not_private_data(self) -> None:
        self._mise("dot", "apply")
        extra = self.home / ".config/ghostty/themes/local-preview"
        extra.write_text("background = 010203\n")
        with (self.source / "mise.local.toml").open("a") as config:
            config.write('\n[bootstrap]\ndotfile_groups = ["shell"]\n')
        self._mise("dot", "apply", "--prune")
        self.assertFalse((self.home / ".config/ghostty/config").exists())
        self.assertEqual(extra.read_text(), "background = 010203\n")
        self.assertTrue((self.home / ".zshrc").is_symlink())

    def test_unapply_preserves_unmanaged_files_and_sources(self) -> None:
        self._mise("dot", "apply")
        private = self.home / ".config/shell/device/local.sh"
        private.parent.mkdir()
        private.write_text("# private fixture\n")
        source = self.source / "config/shell/zshrc"
        original = source.read_bytes()
        self._mise("dot", "unapply")
        self.assertFalse((self.home / ".zshrc").exists())
        self.assertEqual(source.read_bytes(), original)
        self.assertEqual(private.read_text(), "# private fixture\n")

    def test_dry_run_does_not_link_download_or_prepare_workspace_permissions(
        self,
    ) -> None:
        workspace = self.source / "workspaces/daem"
        workspace.chmod(0o755)
        self._mise("dot", "apply", "--dry-run")
        self.assertFalse((self.home / ".zshrc").exists())
        self.assertFalse((self.home / ".local/share/no-agent-summary.js").exists())
        self.assertEqual(stat.S_IMODE(workspace.stat().st_mode), 0o755)

    def test_slurm_commands_are_executable_native_links(self) -> None:
        self._mise("dot", "apply")
        for name in ("sbatchall", "slurm-cancel"):
            target = self.home / ".local/bin" / name
            self.assertTrue(target.is_symlink())
            self.assertTrue(target.stat().st_mode & stat.S_IXUSR)
            self.assertEqual(
                target.read_bytes(),
                (self.source / "config/shell/bin" / name).read_bytes(),
            )

    def test_pixi_fallback_resolves_the_bound_workspace_in_both_shells(self) -> None:
        self._mise("dot", "apply")
        for shell in ("bash", "zsh"):
            executable = shutil.which(shell)
            if executable is None:
                continue
            with self.subTest(shell=shell):
                result = subprocess.run(
                    [
                        executable,
                        "-c",
                        (
                            '. "$HOME/.config/shell/workspaces.sh"; '
                            'printf "%s" "$_dotfiles_repository_manifest"'
                        ),
                    ],
                    env=self.environment,
                    capture_output=True,
                    text=True,
                    check=True,
                )
                self.assertEqual(
                    result.stdout, str(self.source / "workspaces/pixi-base/pixi.toml")
                )

    def test_git_keeps_locks_artifacts_and_device_inputs_untracked(self) -> None:
        assert GIT is not None
        paths = (
            "workspaces/pixi-base/pixi.lock",
            "workspaces/pixi-base/.pixi/envs/default/bin/python",
            "workspaces/daem/daem.lock.toml",
            "workspaces/daem/.daem/state.json",
            "workspaces/mise/config.local.toml",
            "config/nvim/lazy-lock.json",
            "config/shell/lib/device/credentials.sh",
        )
        for relative in paths:
            path = self.source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("generated fixture\n")
        subprocess.run([GIT, "add", "--all"], cwd=self.source, check=True)
        tracked = subprocess.check_output(
            [GIT, "ls-files"], cwd=self.source, text=True
        ).splitlines()
        for relative in paths:
            self.assertNotIn(relative, tracked)
        self.assertIn("workspaces/mise/conf.d/tools.toml", tracked)

    def test_native_bootstrap_prepares_plugins_and_preserves_a_working_generation_on_failure(
        self,
    ) -> None:
        assert MISE is not None
        (self.source / "workspaces/mise/conf.d/tools.toml").write_text("[tools]\n")
        utilities = self.root / "utilities"
        utilities.mkdir()
        proxy = utilities / "mise"
        proxy.write_text(
            '#!/bin/sh\nif [ "${1-}" = --cd ] && [ "${3-}" = which ] && '
            '[ "${4-}" = sheldon ]; then\n'
            'printf "%s\\n" "$HOME/sheldon"\nelse exec "$REAL_MISE" "$@"; fi\n'
        )
        proxy.chmod(0o755)
        sheldon = self.home / "sheldon"
        sheldon.write_text(
            '#!/bin/sh\nset -eu\nshift 4\n[ "${1-}" != --quiet ] || shift\n'
            "case $1 in\nlock) ;;\nsource)\n"
            '[ ! -f "$HOME/fail-source" ] || exit 17\n'
            'printf "%s\\n" "# prepared fixture" ;;\n*) exit 2 ;;\nesac\n'
        )
        sheldon.chmod(0o755)
        self.environment |= {
            "PATH": str(utilities) + os.pathsep + os.defpath,
            "REAL_MISE": MISE,
        }
        self._mise("bootstrap")
        state = self.home / ".local/share/dotfiles/sheldon"
        pointer = state / "current"
        previous = pointer.read_text()
        plugins = state / "generations" / previous.strip() / "zsh-plugins.zsh"
        self.assertEqual(plugins.read_text(), "# prepared fixture\n")
        (self.home / "fail-source").touch()
        self.assertNotEqual(self._run("bootstrap").returncode, 0)
        self.assertEqual(pointer.read_text(), previous)
        self.assertEqual(plugins.read_text(), "# prepared fixture\n")
        self.assertFalse((self.home / ".local/share/mise/installs").exists())

    @unittest.skipUnless(ZSH, "zsh is required")
    def test_preload_preserves_unrelated_options_and_is_idempotent(self) -> None:
        self._mise("dot", "apply")
        hook = self.home / ".local/share/no-agent-summary.js"
        preload = f"--preload={hook}"
        quoted = shlex.quote(preload)
        self.assertEqual(self._summary_options(), [preload])
        self.assertEqual(
            self._summary_options(
                f"--smol --preload='/other path.js' {quoted} {quoted}"
            ),
            ["--smol", "--preload=/other path.js", preload],
        )
        self.assertEqual(
            self._summary_options(
                f"--smol --preload {shlex.quote(str(hook))} {quoted}"
            ),
            ["--smol", preload],
        )

    @unittest.skipUnless(ZSH, "zsh is required")
    def test_preload_disable_fetches_nothing_cleans_inherited_options_and_reenables(
        self,
    ) -> None:
        self._mise("dot", "apply")
        hook = self.home / ".local/share/no-agent-summary.js"
        preload = shlex.quote(f"--preload={hook}")
        self._feature(False, "file:///nonexistent/disabled.js")
        for _ in range(2):
            self._mise("dot", "apply")
            self.assertFalse(hook.exists())
            self.assertEqual(
                self._summary_options(f"--smol {preload} {preload}"), ["--smol"]
            )
            self.assertEqual(self._summary_options(preload), [])
        self._feature(True, self.hook.as_uri())
        self._mise("dot", "apply")
        self.assertEqual(hook.read_bytes(), self.hook.read_bytes())
        self.assertEqual(self._summary_options(), [f"--preload={hook}"])

    def test_failed_download_preserves_working_asset_and_reports_failure(self) -> None:
        self._mise("dot", "apply")
        target = self.home / ".local/share/no-agent-summary.js"
        original = target.read_bytes()
        utilities = self.root / "utilities"
        utilities.mkdir()
        curl = utilities / "curl"
        curl.write_text(
            '#!/bin/sh\nwhile [ "$#" -gt 0 ]; do\n'
            'if [ "$1" = --output ]; then printf partial > "$2"; break; fi\n'
            "shift\ndone\nexit 22\n"
        )
        curl.chmod(0o755)
        self.environment["PATH"] = str(utilities) + os.pathsep + os.defpath
        self.assertNotEqual(self._run("dot", "apply").returncode, 0)
        self.assertEqual(target.read_bytes(), original)
        self.assertEqual(list(target.parent.glob(".no-agent-summary.*")), [])

    def test_asset_update_preserves_private_parent_permissions_and_unexpected_directories(
        self,
    ) -> None:
        parent = self.home / ".local/share"
        parent.mkdir(parents=True, mode=0o700)
        parent.chmod(0o700)
        self._mise("dot", "apply")
        target = parent / "no-agent-summary.js"
        target.unlink()
        target.mkdir()
        marker = target / "keep"
        marker.write_text("unmanaged fixture\n")
        self.assertNotEqual(self._run("dot", "apply").returncode, 0)
        self.assertEqual(marker.read_text(), "unmanaged fixture\n")
        if ZSH is not None:
            self.assertEqual(self._summary_options("--smol"), ["--smol"])
        self._feature(False, "file:///nonexistent/disabled.js")
        self.assertNotEqual(self._run("dot", "apply").returncode, 0)
        self.assertEqual(marker.read_text(), "unmanaged fixture\n")
        self.assertEqual(stat.S_IMODE(parent.stat().st_mode), 0o700)

    @unittest.skipUnless(BUN and ZSH, "native Bun and Zsh are optional")
    def test_preload_quoting_is_accepted_by_native_bun(self) -> None:
        assert BUN is not None and ZSH is not None
        bun = Path(BUN).resolve()
        if bun.name == "mise":
            self.skipTest("bun resolves to a mise shim")
        self.hook.write_text("globalThis.summaryFixture = true;\n")
        self._mise("dot", "apply")
        result = subprocess.run(
            [
                ZSH,
                "-f",
                "-c",
                (
                    '. "$HOME/.zshenv"; exec "$BUN" --eval '
                    "'console.log(globalThis.summaryFixture)'"
                ),
            ],
            env=self.environment | {"BUN": str(bun)},
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        )
        self.assertEqual(result.stdout.strip(), "true")

    @unittest.skipUnless(GHOSTTY, "native Ghostty is optional")
    def test_native_ghostty_reads_linked_config_and_themes(self) -> None:
        assert GHOSTTY is not None
        self._mise("dot", "apply")
        ghostty = self.home / ".config/ghostty"
        for path in (ghostty / "config", *(ghostty / "themes").iterdir()):
            with self.subTest(path=path.name):
                subprocess.run(
                    [GHOSTTY, "+validate-config", f"--config-file={path}"],
                    env=self.environment,
                    capture_output=True,
                    text=True,
                    timeout=30,
                    check=True,
                )

    @unittest.skipUnless(DAEM, "native daem is optional")
    def test_native_daem_edits_and_applies_only_the_fixture_workspace(self) -> None:
        assert DAEM is not None
        self._mise("dot", "apply")
        manifest = self.source / "workspaces/daem/daem.toml"
        manifest.write_text(
            'version = 1\ntargets = ["pi"]\n[defaults]\nscope = "global"\n'
        )
        fixture = self.root / "instruction.md"
        fixture.write_text("Synthetic native authoring fixture.\n")
        for arguments in (
            ("add", "instruction", "fixture", str(fixture), "--json"),
            ("apply", "--dry-run", "--json"),
            ("apply", "--yes", "--json"),
        ):
            subprocess.run(
                [DAEM, *arguments],
                env=self.environment,
                cwd=self.root,
                capture_output=True,
                text=True,
                timeout=30,
                check=True,
            )
        self.assertTrue((self.home / ".config/daem").is_symlink())
        self.assertTrue((manifest.parent / "daem.lock.toml").is_file())
        self.assertEqual(
            (self.home / ".pi/agent/AGENTS.md").read_bytes(), fixture.read_bytes()
        )
        self._mise("dot", "apply")
        self.assertEqual(
            (self.home / ".pi/agent/AGENTS.md").read_bytes(), fixture.read_bytes()
        )

    def test_repointing_file_links_preserves_former_sources_and_vim_runtime(
        self,
    ) -> None:
        former = self.root / "former"
        former.mkdir()
        old_config = former / "vimrc"
        old_config.write_text('" former configuration\n')
        old_runtime = former / "vim"
        old_runtime.mkdir()
        marker = old_runtime / "installed-plugin"
        marker.write_text("preserved runtime\n")
        runtime = self.home / ".vim"
        runtime.symlink_to(old_runtime, target_is_directory=True)
        (self.home / ".vimrc").symlink_to(old_config)
        metadata = self.home / ".config/nvim/.git/preserved"
        metadata.parent.mkdir(parents=True)
        metadata.write_text("preserved repository\n")
        self._mise("dot", "apply")
        self.assertEqual(old_config.read_text(), '" former configuration\n')
        self.assertEqual(runtime.readlink(), old_runtime)
        self.assertEqual(marker.read_text(), "preserved runtime\n")
        self.assertEqual(metadata.read_text(), "preserved repository\n")
        self.assertEqual(
            (self.home / ".vimrc").resolve(), self.source / "config/vim/vimrc"
        )

    def test_prune_keeps_native_restore_state_in_a_deselected_group(self) -> None:
        self._mise("dot", "apply")
        lock = self.home / ".config/nvim/lazy-lock.json"
        lock.write_text("local restore state\n")
        with (self.source / "mise.local.toml").open("a") as config:
            config.write('\n[bootstrap]\ndotfile_groups = ["shell"]\n')
        self._mise("dot", "apply", "--prune")
        self.assertFalse((self.home / ".config/nvim/init.lua").exists())
        self.assertEqual(lock.read_text(), "local restore state\n")

    @unittest.skipUnless(ZSH, "zsh is required")
    def test_missing_or_disabled_preload_cleans_both_inherited_argument_forms(
        self,
    ) -> None:
        self._mise("dot", "apply")
        hook = self.home / ".local/share/no-agent-summary.js"
        preload = shlex.quote(f"--preload={hook}")
        hook.unlink()
        inherited = f"--preload {shlex.quote(str(hook))} --smol {preload}"
        self.assertEqual(self._summary_options(inherited), ["--smol"])
        self._feature(False, "file:///nonexistent/disabled.js")
        self._mise("dot", "apply")
        self.assertEqual(self._summary_options(inherited), ["--smol"])

    def test_disabled_asset_needs_no_curl_and_invalid_mode_is_rejected(self) -> None:
        script = self.source / "features/claude-no-agent-summary/apply.sh"
        target = self.home / ".local/share/no-agent-summary.js"
        target.parent.mkdir(parents=True)
        target.write_text("fixture\n")
        utilities = self.root / "removal-utilities"
        utilities.mkdir()
        rm = shutil.which("rm")
        assert rm is not None
        (utilities / "rm").symlink_to(rm)
        environment = self.environment | {"PATH": str(utilities)}
        result = subprocess.run(
            ["/bin/sh", str(script), "off", "file:///nonexistent/disabled.js"],
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(target.exists())
        result = subprocess.run(
            ["/bin/sh", str(script), "invalid", self.hook.as_uri()],
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(target.exists())

    def test_explicit_trust_allows_global_catalog_use_after_binding(self) -> None:
        assert MISE is not None
        self.environment.pop("MISE_TRUSTED_CONFIG_PATHS")
        self.environment.pop("MISE_YES")

        temporary = tempfile.TemporaryDirectory(prefix="mise-native-node-")
        self.addCleanup(temporary.cleanup)
        prefix = Path(temporary.name).resolve()
        node = prefix / "bin/node"
        node.parent.mkdir()
        node.write_text('#!/bin/sh\nprintf "v20.0.0\\n"\n')
        node.chmod(0o755)

        catalog = self.source / "workspaces/mise/conf.d/tools.toml"
        catalog.write_text(
            "[tools]\nnode = { version = " + json.dumps("path:" + str(prefix)) + " }\n"
        )

        for config in ("mise.toml", "mise.local.toml"):
            self._mise("trust", config)
        self._mise("dot", "apply")
        self._mise("trust", str(self.home / ".config/mise/conf.d/tools.toml"))

        result = subprocess.run(
            [MISE, "--cd", str(self.home), "which", "node"],
            env=self.environment
            | {
                "MISE_GLOBAL_CONFIG_FILE": str(
                    self.source / "workspaces/mise/config.toml"
                )
            },
            cwd=self.source,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(Path(result.stdout.strip()), node)


if __name__ == "__main__":
    unittest.main()
