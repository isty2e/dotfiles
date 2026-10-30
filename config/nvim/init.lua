vim.g.mapleader = ","
vim.g.maplocalleader = ","
require "config.options"
require "config.keymaps"

if require("config.bootstrap").setup() then require("config.lsp").setup() end
