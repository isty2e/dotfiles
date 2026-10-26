local M = {}

local function manager_exists(path)
  local entrypoint = vim.uv.fs_stat(path .. "/lua/lazy/init.lua")
  return entrypoint ~= nil and entrypoint.type == "file"
end

local function install_manager(path)
  if vim.uv.fs_lstat(path) then
    error("NvimSetup: existing lazy.nvim path is incomplete; move it aside before retrying: " .. path)
  end
  if vim.fn.executable "git" == 0 then error "NvimSetup: Git is required to install lazy.nvim" end

  local parent = vim.fs.dirname(path)
  vim.fn.mkdir(parent, "p")
  local temporary, problem = vim.uv.fs_mkdtemp(parent .. "/.lazy-XXXXXX")
  if not temporary then error("NvimSetup: cannot create a staging directory: " .. problem) end

  vim.notify "NvimSetup: installing lazy.nvim"
  vim.cmd "redraw"
  local output = vim.fn.system {
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    temporary,
  }
  if vim.v.shell_error ~= 0 or not manager_exists(temporary) then
    vim.fn.delete(temporary, "rf")
    error("NvimSetup: lazy.nvim clone failed; run :NvimSetup to retry.\n" .. output)
  end

  local published, message = vim.uv.fs_rename(temporary, path)
  if not published then
    vim.fn.delete(temporary, "rf")
    error("NvimSetup: cannot publish lazy.nvim: " .. message)
  end
end

function M.setup()
  local path = vim.fs.normalize(vim.fn.fnamemodify(vim.env.LAZY or vim.fn.stdpath "data" .. "/lazy/lazy.nvim", ":p"))
  local function load_plugins(install_missing)
    if not vim.g.lazy_did_setup then
      vim.opt.rtp:prepend(path)
      require "lazy_setup"(install_missing)
    end
  end

  vim.api.nvim_create_user_command("NvimSetup", function()
    if not manager_exists(path) then install_manager(path) end
    load_plugins(true)
    require("lazy").install { wait = true, lockfile = true }
    vim.notify "Review :Lazy for installation results, then restart Neovim."
  end, { desc = "Install lazy.nvim and missing plugins" })

  if not manager_exists(path) then
    vim.notify(
      "lazy.nvim is not installed; run :NvimSetup, then restart Neovim. Core editing is available.",
      vim.log.levels.WARN
    )
    return false
  end
  load_plugins(false)
  return true
end

return M
