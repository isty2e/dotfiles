local source = assert(vim.env.NVIM_SETUP_SOURCE)
local root = assert(vim.env.NVIM_SETUP_TEST_ROOT)
vim.opt.rtp:prepend(source)
vim.fn.mkdir(root .. "/bin", "p")
local calls = root .. "/git.calls"
local mode = root .. "/clone.mode"
local fixture = root .. "/manager fixture"
vim.fn.mkdir(fixture .. "/lua/lazy", "p")
vim.fn.writefile(
  vim.split(
    [[return { install = function(options)
  assert(options.wait and options.lockfile)
  _G.setup_installs = _G.setup_installs + 1
end }]],
    "\n"
  ),
  fixture .. "/lua/lazy/init.lua"
)
local git = root .. "/bin/git"
vim.fn.writefile({
  "#!/bin/sh",
  'printf "clone\\n" >> "$NVIM_SETUP_TEST_ROOT/git.calls"',
  "for destination do :; done",
  'mkdir -p "$destination/partial"',
  'test "$(cat "$NVIM_SETUP_TEST_ROOT/clone.mode")" != empty || exit 0',
  'test "$(cat "$NVIM_SETUP_TEST_ROOT/clone.mode")" = success || exit 1',
  'cp -R "$NVIM_SETUP_TEST_ROOT/manager fixture/." "$destination/"',
}, git)
vim.fn.setfperm(git, "rwx------")
local original_path = vim.env.PATH
vim.env.PATH = root .. "/bin:" .. original_path
vim.fn.writefile({ "failure" }, mode)
_G.setup_installs = 0
package.preload["lazy_setup"] = function()
  return function(install_missing)
    _G.setup_policy = install_missing
    vim.g.lazy_did_setup = true
  end
end
package.preload["config.lsp"] = function()
  return { setup = function() end }
end
local function start(path)
  vim.env.LAZY = path
  vim.g.lazy_did_setup = nil
  package.loaded.lazy = nil
  package.loaded.lazy_setup = nil
  dofile(source .. "/init.lua")
end
local function clone_count() return vim.fn.filereadable(calls) == 1 and #vim.fn.readfile(calls) or 0 end
local manager = root .. "/data with spaces/lazy.nvim"
start(manager)
assert(clone_count() == 0, "startup attempted a clone")
local ok = pcall(vim.cmd, "NvimSetup")
assert(not ok, "a failed clone was accepted")
assert(not vim.uv.fs_lstat(manager), "failed clone was published")
assert(#vim.fn.glob(root .. "/data with spaces/.lazy-*", false, true) == 0, "failed staging directory remains")
assert(_G.setup_installs == 0, "plugin installation followed a failed manager clone")

vim.fn.writefile({ "success" }, mode)
vim.cmd "NvimSetup"
assert(vim.fn.filereadable(manager .. "/lua/lazy/init.lua") == 1)
assert(clone_count() == 2 and _G.setup_installs == 1)
assert(_G.setup_policy == true, "explicit cold setup did not enable native missing installation")
vim.fn.writefile({ "existing manager state" }, manager .. "/keep")
vim.cmd "NvimSetup"
assert(clone_count() == 2 and _G.setup_installs == 2, "repeat setup did not reuse the manager")
assert(vim.fn.readfile(manager .. "/keep")[1] == "existing manager state")
start(manager)
assert(_G.setup_policy == false and _G.setup_installs == 2 and clone_count() == 2, "normal startup installed plugins")

local incomplete = root .. "/incomplete"
vim.fn.mkdir(incomplete, "p")
vim.fn.writefile({ "preserve this" }, incomplete .. "/keep")
start(incomplete)
ok = pcall(vim.cmd, "NvimSetup")
assert(not ok and clone_count() == 2)
assert(vim.fn.readfile(incomplete .. "/keep")[1] == "preserve this", "existing incomplete manager was modified")

vim.fn.writefile({ "empty" }, mode)
local invalid = root .. "/invalid-clone/lazy.nvim"
start(invalid)
ok = pcall(vim.cmd, "NvimSetup")
assert(not ok and not vim.uv.fs_lstat(invalid), "invalid clone was published")

vim.fn.mkdir(root .. "/empty-bin", "p")
vim.env.PATH = root .. "/empty-bin"
start(root .. "/without-git/lazy.nvim")
ok = pcall(vim.cmd, "NvimSetup")
assert(not ok and not vim.uv.fs_lstat(root .. "/without-git"), "missing Git caused installation effects")
vim.env.PATH = original_path
print "PASS: no startup install; first-use failure/retry; path with spaces; manager reuse; incomplete-path preservation; missing Git"
