vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.wrap = true
vim.opt.termguicolors = true
vim.opt.background = "light"
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.updatetime = 250
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.statusline = " %{mode()} %f %m%r %{get(b:,'gitsigns_head','')} %{get(b:,'gitsigns_status','')}%=%l:%c %p%% "
vim.diagnostic.config { virtual_text = true, signs = true, underline = true, severity_sort = true }

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("PersonalIndent", { clear = true }),
  pattern = { "python", "rust", "swift" },
  callback = function()
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 4
    vim.bo.tabstop = 4
  end,
})
