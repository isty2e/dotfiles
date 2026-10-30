return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    on_attach = function(buffer)
      vim.keymap.set("n", "]c", function() require("gitsigns").nav_hunk "next" end, { buffer = buffer, desc = "Next Git hunk" })
      vim.keymap.set("n", "[c", function() require("gitsigns").nav_hunk "prev" end, { buffer = buffer, desc = "Previous Git hunk" })
      vim.keymap.set("n", "<Leader>gp", require("gitsigns").preview_hunk, { buffer = buffer, desc = "Preview Git hunk" })
      vim.keymap.set("n", "<Leader>gb", require("gitsigns").blame_line, { buffer = buffer, desc = "Blame line" })
    end,
  },
}
