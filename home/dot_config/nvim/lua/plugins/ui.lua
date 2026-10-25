return {
  {
    "lewis6991/satellite.nvim",
    event = "BufReadPost",
    opts = { excluded_filetypes = { "prompt", "TelescopePrompt", "neo-tree", "neo-tree-popup", "notify" } },
  },
  {
    "rcarriga/nvim-notify",
    lazy = false,
    opts = { timeout = 2500, background_colour = "#ffffff" },
    config = function(_, opts)
      require("notify").setup(opts)
      vim.notify = require "notify"
    end,
  },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = { scope = { enabled = false } } },
  {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    config = function() require("illuminate").configure { delay = 100 } end,
  },
}
