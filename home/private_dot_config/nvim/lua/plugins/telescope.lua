return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope-fzf-native.nvim" },
  opts = function()
    local actions = require "telescope.actions"
    return { defaults = { sorting_strategy = "ascending", mappings = { n = {
      n = actions.move_selection_next,
      e = actions.move_selection_previous,
      j = false,
      k = false,
      I = actions.move_to_bottom,
      L = false,
    } } } }
  end,
  config = function(_, opts)
    require("telescope").setup(opts)
    local directory = require("lazy.core.config").plugins["telescope-fzf-native.nvim"].dir
    if vim.uv.fs_stat(directory .. "/build/libfzf.so") then require("telescope").load_extension "fzf" end
  end,
  keys = {
    { "<Leader>ff", function() require("telescope.builtin").find_files { no_ignore = true } end, desc = "Find all files" },
    { "<Leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Find words" },
    { "<Leader>fb", function() require("telescope.builtin").buffers() end, desc = "Find buffers" },
    { "<Leader>ft", function() require("telescope.builtin").colorscheme { enable_preview = true } end, desc = "Choose theme" },
  },
}
