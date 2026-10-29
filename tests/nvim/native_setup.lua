local source = assert(vim.env.NVIM_SETUP_SOURCE)
local root = assert(vim.env.NVIM_SETUP_TEST_ROOT)
local manager_source = assert(vim.env.NVIM_SETUP_NATIVE_LAZY)
local real_git = assert(vim.env.NVIM_SETUP_REAL_GIT)
vim.go.loadplugins = true
vim.fn.mkdir(root, "p")
local function git(path, ...)
  local command = { real_git, "-C", path }
  vim.list_extend(command, { ... })
  local output = vim.fn.system(command)
  assert(vim.v.shell_error == 0, output)
  return vim.trim(output)
end
local function commit(path, value)
  vim.fn.writefile({ value }, path .. "/value")
  git(path, "add", ".")
  git(
    path,
    "-c",
    "user.name=Fixture",
    "-c",
    "user.email=fixture@example.invalid",
    "-c",
    "commit.gpgsign=false",
    "commit",
    "-qm",
    "fixture"
  )
  return git(path, "rev-parse", "HEAD")
end
local function origin(name)
  local path = root .. "/" .. name
  vim.fn.mkdir(path, "p")
  git(path, "init", "-q")
  local first = commit(path, "first")
  commit(path, "second")
  return path, first
end
local existing_origin, existing_lock = origin "existing-origin"
local missing_origin, missing_lock = origin "missing-origin"
local unlocked_origin, declared_commit = origin "unlocked-origin"
local mirror = root .. "/manager-mirror"
vim.fn.mkdir(mirror, "p")
for _, directory in ipairs { "lua", "plugin", "doc" } do
  if vim.fn.isdirectory(manager_source .. "/" .. directory) == 1 then
    vim.fn.system { "cp", "-R", manager_source .. "/" .. directory, mirror .. "/" .. directory }
    assert(vim.v.shell_error == 0)
  end
end
git(mirror, "init", "-q")
commit(mirror, "native manager fixture")
git(mirror, "branch", "stable")
local data = vim.fn.stdpath "data" .. "/lazy"
vim.fn.mkdir(data, "p")
local existing = data .. "/existing"
vim.fn.system { real_git, "clone", "-q", existing_origin, existing }
assert(vim.v.shell_error == 0)
local existing_head = git(existing, "rev-parse", "HEAD")
vim.fn.writefile({ "local modification" }, existing .. "/value")
local lockfile = root .. "/lazy-lock.json"
vim.fn.writefile({
  vim.json.encode {
    existing = { branch = git(existing_origin, "branch", "--show-current"), commit = existing_lock },
    missing = { branch = git(missing_origin, "branch", "--show-current"), commit = missing_lock },
  },
}, lockfile)

vim.fn.mkdir(root .. "/bin", "p")
vim.env.NVIM_SETUP_MANAGER_MIRROR = mirror
local shim = root .. "/bin/git"
vim.fn.writefile({
  "#!/bin/sh",
  'for argument do if test "$argument" = https://github.com/folke/lazy.nvim.git; then',
  "  for destination do :; done",
  '  exec "$NVIM_SETUP_REAL_GIT" clone --branch stable "$NVIM_SETUP_MANAGER_MIRROR" "$destination"',
  "fi; done",
  'exec "$NVIM_SETUP_REAL_GIT" "$@"',
}, shim)
vim.fn.setfperm(shim, "rwx------")
vim.env.PATH = root .. "/bin:" .. vim.env.PATH
package.preload["lazy_setup"] = function()
  return function(install_missing)
    require("lazy").setup({
      { name = "existing", url = "file://" .. existing_origin },
      { name = "missing", url = "file://" .. missing_origin },
      { name = "unlocked", url = "file://" .. unlocked_origin, commit = declared_commit },
    }, {
      root = data,
      lockfile = lockfile,
      install = { missing = install_missing },
      checker = { enabled = false },
      rocks = { enabled = false },
      pkg = { enabled = false },
      local_spec = false,
    })
  end
end
package.preload["config.lsp"] = function()
  return { setup = function() end }
end
vim.opt.rtp:prepend(source)
dofile(source .. "/init.lua")
assert(not vim.uv.fs_stat(data .. "/lazy.nvim"), "startup installed the manager")
vim.cmd "NvimSetup"
assert(vim.fn.filereadable(data .. "/lazy.nvim/lua/lazy/init.lua") == 1)
assert(git(data .. "/missing", "rev-parse", "HEAD") == missing_lock, "missing plugin did not use the lockfile")
assert(git(data .. "/unlocked", "rev-parse", "HEAD") == declared_commit, "unlocked plugin ignored its declaration")
assert(vim.json.decode(table.concat(vim.fn.readfile(lockfile), "\n")).unlocked.commit == declared_commit)
assert(git(existing, "rev-parse", "HEAD") == existing_head, "existing plugin was restored or updated")
assert(vim.fn.readfile(existing .. "/value")[1] == "local modification", "existing local work changed")
vim.cmd "NvimSetup"
assert(git(existing, "rev-parse", "HEAD") == existing_head)
assert(vim.fn.readfile(existing .. "/value")[1] == "local modification")
print "PASS: native lazy.nvim bootstrap/install; locked missing plugin; existing revision/local work preserved; repeat setup"
